require 'sinatra'
require 'grocer'
require 'geokit'
require 'active_record'
require 'uri'
 
db = URI.parse(ENV['DATABASE_URL'] || 'postgres://127.0.0.1/herder')
ActiveRecord::Base.establish_connection(
  :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
  :host     => db.host,
  :port     => db.port,
  :username => db.user,
  :password => db.password,
  :database => db.path[1..-1],
  :encoding => 'utf8'
)

class User < ActiveRecord::Base

  def as_json(options={})
    result = {
      :deviceToken => self.device_token,
      :username => self.username,
      :latitude => self.latitude,
      :longitude => self.longitude,
      #:timestamp => self.timestamp
      :has_arrived => self.has_arrived,
    }
    return result
  end
end

class App
  attr_accessor :pusher_dev, :pusher_prod
end

class Herder < Sinatra::Base

  configure do
    app = App.new
    if File.exist?("#{Dir.pwd}/config/development.pem")
      puts "Found development pem file"
      app.pusher_dev = Grocer.pusher(
        certificate: "#{Dir.pwd}/config/development.pem",
        passphrase:  "herder",
        gateway:     "gateway.sandbox.push.apple.com",
      )
    end
    if File.exist?("#{Dir.pwd}/config/production.pem")
      puts "Found production pem file"
      app.pusher_prod = Grocer.pusher(
        certificate: "#{Dir.pwd}/config/production.pem",   # required
        passphrase:  "herder",
        gateway:     "gateway.push.apple.com",
      )
    end
    # setup location
    Geokit::default_formula = :flat
    Geokit::Geocoders::google = "AIzaSyC_7Re3Idfb1YCaC8PWeEBv3Q1PE-_-EF0"

    set :app, app
    set :loc_seatme, Geokit::LatLng.new(37.7912817, -122.4012656)
  end

  get '/' do
    return 403
  end

  get '/location' do
    users = User.find(:all)
    return users.to_json
  end

  # update existing user with location or create new user
  post '/location' do
    data = JSON.parse(request.body.read)
    if not data.has_key?("deviceToken")
      return 400  # bad request
    end

    user = User.find_or_initialize_by_device_token(:device_token => data["deviceToken"])
    user.username = data["username"]
    user.latitude = data["latitude"]
    user.longitude = data["longitude"]
    user.save

    if user.has_arrived
      return 200
    end
    # do location queries
    loc = Geokit::LatLng.new(user.latitude, user.longitude)
    distance = loc.distance_to(settings.loc_seatme)
    puts distance
    if distance <= 0.01
      # user is only a short distance away
      # send notifications that they have arrived

      # get correct pusher depending on environment
      pusher = settings.app.pusher_prod
      if (data.has_key?("environment") && data["environment"] == "development")
        pusher = settings.app.pusher_dev
      end

      # find all users except this
      all_other_users = User.find(:all, :conditions => ["id != ?", user.id])

      # make a notification for each user and push it out
      alert = user.username + " is here!"

      all_other_users.each do |u|
        notification = Grocer::Notification.new do |n|
          n.device_token = u.device_token
          n.alert = alert
        end
        pusher.push(notification)
      end

      user.has_arrived = true
      user.save
    end

  end

end
