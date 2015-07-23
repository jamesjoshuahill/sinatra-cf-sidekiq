##
# Example from https://github.com/mperham/sidekiq/blob/10c1b1ae21e2812475d4832a4d9fcefc46e5ace5/examples/sinkiq.rb
#

# Make sure you have Sinatra installed, then start sidekiq with
# ./bin/sidekiq -r ./examples/sinkiq.rb
# Simply run Sinatra with
# ruby examples/sinkiq.rb
# and then browse to http://localhost:4567
#
require 'sinatra'
require 'sidekiq'
require 'redis'
require 'sidekiq/api'
require "json"

services = JSON.parse(ENV.fetch('VCAP_SERVICES'))

redis_service = services["user-provided"].detect do |service|
  service["name"] == "redislabs"
end
redis = redis_service.fetch('credentials')
redis_conf = {
  host: redis.fetch("host"),
  port: redis.fetch("port"),
  password: redis.fetch("password")
}

Sidekiq.configure_server do |config|
  config.redis = redis_conf
end

Sidekiq.configure_client do |config|
  config.redis = redis_conf
end

class SinatraWorker
  include Sidekiq::Worker

  def perform(msg="lulz you forgot a msg!")
    Sidekiq.redis do |conn|
      conn.lpush("sinkiq-example-messages", msg)
    end
  end
end

get '/' do
  stats = Sidekiq::Stats.new
  @failed = stats.failed
  @processed = stats.processed
  @messages = Sidekiq.redis do |conn|
    conn.lrange('sinkiq-example-messages', 0, -1)
  end
  erb :index
end

post '/msg' do
  SinatraWorker.perform_async params[:msg]
  redirect to('/')
end

__END__

@@ layout
<html>
  <head>
    <title>Sinatra + Sidekiq</title>
    <body>
      <%= yield %>
    </body>
</html>

@@ index
  <h1>Sinatra + Sidekiq Example</h1>
  <h2>Failed: <%= @failed %></h2>
  <h2>Processed: <%= @processed %></h2>

  <form method="post" action="/msg">
    <input type="text" name="msg">
    <input type="submit" value="Add Message">
  </form>

  <a href="/">Refresh page</a>

  <h3>Messages</h3>
  <% @messages.each do |msg| %>
    <p><%= msg %></p>
  <% end %>
