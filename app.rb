require 'sinatra'
require 'yajl'
require 'httparty'

# At what log-line count per time unit should a system be auto-muted?
MAX_VELOCITY = ENV['PAPERTRAIL_VELOCITY'] || 100

# How many alert invocations over the limit are required before the muting/unmuting occurs?
SUSTAINED_DURATION = ENV['PAPERTRAIL_DURATION'] || 10

# Provide your API key as an env var
API_KEY = ENV['PAPERTRAIL_API_KEY']

def mute_system_name(name, id)
  headers = { 'X-Papertrail-Token' => API_KEY }
  query = "system[name]=#{name}-muted"
  response = HTTParty.put("https://papertrailapp.com/api/v1/systems/#{id}.json", query: query, headers: headers)
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
  # Sanity checking
  return [400, ["Not a valid count alert payload"]] unless counts
  return [400, ["Too many sources to check"]] if counts.length > 100

  # Take each source and figure out its count and process it
  counts.each do |source|
    system_name = source['source_name']
    system_id = source['source_id']
    line_count = source['timeseries'].values.reduce(&:+)

    if line_count > MAX_VELOCITY && !system_name.match(/muted/)
      if mute_invocations[system_name] > SUSTAINED_DURATION
        puts "Muting #{system_name}, it has been above #{MAX_VELOCITY} for #{SUSTAINED_DURATION} invocations"
        response = mute_system_name(system_name, system_id)
        if response.status == 200
          puts "System updated: #{response.body}"
          mute_invocations[system_name] = 0
        else
          puts "System update failed: #{response.status} #{response.body}"
          # This branch doesn't reset the invocations, because the system didn't get muted.
        end
      else
        puts "#{system_name} is above #{MAX_VELOCITY}, incrementing mute invocations"
        mute_invocations[system_name] += 1
      end
    else
      puts "#{system_name} not above #{MAX_VELOCITY}, resetting mute invocations"
      mute_invocations[system_name] = 0
    end
  end

  200
end