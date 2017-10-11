require 'sinatra'
require 'yajl'
require 'httparty'

# At what log-line count per time unit should a system be auto-muted?
MAX_VELOCITY = ENV['PAPERTRAIL_VELOCITY'] || 100

# How many alert invocations over the limit are required before the muting/unmuting occurs?
SUSTAINED_DURATION = ENV['PAPERTRAIL_VELOCITY'] || 10

# Provide your API key as an env var
API_KEY = ENV['PAPERTRAIL_API_KEY']

def mute_system_name(name, id)
  headers = { 'X-Papertrail-Token' => API_KEY }
  query = "system[name]=#{name}-muted"
  response = HTTParty.put("https://papertrailapp.com/api/v1/systems/#{id}.json", query: query, headers: headers)
  puts response
end

# Initialize the number of times the alert has exceeded the threshold
mute_invocations = Hash.new(0)

get '/' do
  'This is a webhook app that uses Papertrail alerts to mute their senders.'
end

get '/log' do
 'This app accepts POST requests to /log in the format of Papertrail count-only webhook alerts.'
end

post '/log' do
  payload = Yajl::Parser.parse(params[:payload])
  counts = payload['counts']
  counts.each do |source|
    system_name = source['source_name']
    system_id = source['source_id']
    line_count = source['timeseries'].values.reduce(&:+)
    if line_count > MAX_VELOCITY && !system_name.match(/muted/)
      if mute_invocations[system_name] > SUSTAINED_DURATION
        puts "Muting #{system_name}, it has been above #{MAX_VELOCITY} for #{SUSTAINED_DURATION} invocations"
        mute_system_name(system_name, system_id)
        mute_invocations[system_name] = 0
      else
        puts "#{system_name} is above #{MAX_VELOCITY}, incrementing mute invocations"
        mute_invocations[system_name] += 1
      end
    else
      puts "#{system_name} not above threshold"
    end
  end
  200
end