require 'stringio'
require 'google/cloud/storage'
require 'dotenv'
require 'json'

##
#
# This script uploads the actual event map HTML to S3, where it can be used as
# an iframe. This script can essentially be considered the deploy script for
# the event map.
#
##

# Load environment variables
Dotenv.load

# Initialize our Google Cloud client that lets us upload
# the event data
storage = Google::Cloud::Storage.new
bucket = storage.bucket ENV['GCS_BUCKET']

# Upload the event map
bucket.create_file 'event_map.html', 'map.html'

# Upload zip codes
bucket.create_file 'zip_codes.json', 'zip_codes.json'
