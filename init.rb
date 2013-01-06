require 'sinatra/base'
require 'sinatra/json'
require 'grocer'
 
class App
  attr_accessor :bundleID, :pusher_dev, :pusher_prod
end
 
 
class Notify < Sinatra::Base
 
  configure do
    dirs = Dir.entries("#{Dir.pwd}/apps").select {|entry| File.directory? File.join("#{Dir.pwd}/apps",entry) and !(entry =='.' || entry == '..') }
    APPS = Hash.new
    dirs.each do |directory|
      app = App.new
      app.bundleID = directory
      if File.exist?("#{Dir.pwd}/apps/#{directory}/push-development.pem")
        puts "#{directory} has push-development.pem"
        app.pusher_dev = Grocer.pusher(
          certificate: "#{Dir.pwd}/apps/#{directory}/push-development.pem",      # required
          gateway:     "gateway.sandbox.push.apple.com",
        )
      end
      if File.exist?("#{Dir.pwd}/apps/#{directory}/push-production.pem")
        puts "#{directory} has push-production.pem"
        app.pusher_prod = Grocer.pusher(
          certificate: "#{Dir.pwd}/apps/#{directory}/push-production.pem",      # required
          gateway:     "gateway.push.apple.com",
        )
      end

      APPS[directory] = app
    end

  end

  get '/' do
    return 403
  end

  post '/send' do
    data = JSON.parse(request.body.read)
    puts data

    # `device_token` and either `alert` or `badge` are required.
    if APPS.has_key?(data["bundleID"])

      pusher = APPS[data["bundleID"]].pusher_prod
      if (data.has_key?("environment") && data["environment"] == "development")
        pusher = APPS[data["bundleID"]].pusher_dev
      end

      notification = Grocer::Notification.new(
        device_token: data["notification"]["device_token"],
        alert: data["notification"]["alert"],
        badge: data["notification"]["badge"],
        sound: data["notification"]["sound"]
      )

      if pusher.nil?
        return 500
      end

      pusher.push(notification)
    else
      return 400
    end

    return 200
  end

end
