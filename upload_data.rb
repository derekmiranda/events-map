require 'json'
require 'stringio'
require 'google/cloud/storage'
require 'dotenv'
require_relative 'hubs_airtable'
require_relative 'events_airtable'
require_relative 'mobilize_america'
require_relative 'every_action'

##
#
# This script triggers API gets events data from all of our event sources
# (mobilize america, events airtable, etc), associates them with hubs, and
# converts them all to a common JSON form. Then it uploads the result to S3,
# where it's stored in a public file that can be accessed by Javascript in
# event_map.html.
#
##

# Load environment variables (API keys, etc)
Dotenv.load

# Array to store the event objects
events = []

# Load event data from our EveryAction account(s)
ENV['EVERY_ACTION_INFO'].to_s.split(',').each do |api_key|
  ea_client = EveryActionClient.new(api_key)
  events += ea_client.events
end

# Load event data from our MobilizeAmerica account(s)
(ENV['MOBILIZE_AMERICA_INFO'] || '').split(',').each do |ma_info|
  api_key, org_id = ma_info.split('_')
  ma_client = MobilizeAmericaClient.new(api_key, org_id)
  events += ma_client.events
end

entries = events.select(&:should_appear_on_map?).map(&:map_entry)

# Add event types to the data, mapping them to a common
# user-friendly string using Airtable data
entries = EventTypeDictionary.transform(entries)

# Sort the events by their start date, using location as a backup
entries.sort_by! { |e| [e[:start_date], e[:city] || e[:location_name] || 'zzz'] }

# Convert everything to JSON, with the current timestamp (to help with
# debugging)
map_json = JSON.dump({
  updated_at: Time.now.to_s,
  map_data: entries
})

# Initialize our Google Cloud client that lets us upload
# the event data
storage = Google::Cloud::Storage.new
bucket = storage.bucket ENV['GCS_BUCKET']

bucket.create_file StringIO.new(map_json), 'events.json'
