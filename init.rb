require 'sinatra'
require 'geokit'
require 'active_record'
require 'uri'
require 'apns'
 
db = URI.parse(ENV['DATABASE_URL'] || 'postgres://localhost/herder')
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
      :distance => self.distance,
      #:timestamp => self.timestamp,
      :has_arrived => self.has_arrived,
    }
    return result
  end
end

class Herder < Sinatra::Base

  configure do
    if File.exist?("#{Dir.pwd}/config/cert.pem")
      puts "Found pem file"
      APNS.pem  = "#{Dir.pwd}/config/cert.pem"
      APNS.pass = "herder"
      APNS.cache_connections = true
    end
    # setup location
    Geokit::default_formula = :sphere
    Geokit::default_units = :kms
    Geokit::Geocoders::google = "AIzaSyC_7Re3Idfb1YCaC8PWeEBv3Q1PE-_-EF0"

    set :loc_seatme, Geokit::LatLng.new(37.79125, -122.40128)
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
    # get distance to target in meters
    loc = Geokit::LatLng.new(user.latitude, user.longitude)
    distance = loc.distance_to(settings.loc_seatme)
    distance = distance * 1000
    user.distance = distance
    if distance <= 50
      # user is only a short distance away
      # send notifications that they have arrived

      # find all users except this
      all_other_users = User.find(:all, :conditions => ["id != ?", user.id])

      # make a notification for each user and push it out
      alert = user.username + " is here!"

      APNS.establish_notification_connection
      all_other_users.each do |u|
        if APNS.has_notification_connection?
          APNS.send_notification(u.device_token, alert)
        end
      end

      user.has_arrived = true
    end

    user.save

  end

end
