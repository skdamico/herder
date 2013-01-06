require 'sinatra/base'
require 'sinatra/json'
require 'grocer'
require 'geokit'
 
class App
  attr_accessor :pusher_dev, :pusher_prod
end
 
 
class Notify < Sinatra::Base
 
  configure do
    app = App.new
    if File.exist?("#{Dir.pwd}/cert/development.pem")
      puts "Found development pem file"
      app.pusher_dev = Grocer.pusher(
        certificate: "#{Dir.pwd}/cert/development.pem",
        gateway:     "gateway.sandbox.push.apple.com",
      )
    end
    if File.exist?("#{Dir.pwd}/cert/production.pem")
      puts "Found production pem file"
      app.pusher_prod = Grocer.pusher(
        certificate: "#{Dir.pwd}/cert/production.pem",   # required
        gateway:     "gateway.push.apple.com",
      )
    end
  end

  get '/' do
    return 403
  end

  post '/send' do
    data = JSON.parse(request.body.read)
    puts data

    # `device_token` and either `alert` or `badge` are required.
    pusher = app.pusher_prod
    if (data.has_key?("environment") && data["environment"] == "development")
      pusher = app.pusher_dev
    end

    notification = Grocer::Notification.new(
      device_token: data["notification"]["device_token"],
      alert:data["notification"]["alert"],
      badge:data["notification"]["badge"],
      sound:data["notification"]["sound"]
    )

    if pusher.nil?
      return 500
    end

    pusher.push(notification)

    return 200
  end

end

class HerderLocation < Sinatra::Base
  get '/locations' do
    
  end
end
