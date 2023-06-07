require "rubygems"
require "optimist"

OPTS = Optimist::options do
    banner <<-EOS

Exports vision scores from API endpoint specified in config.yml. This exports
*all* vision scores returned by the API for each observation it visits, which is
a bit different from export_vision_test_data.rb and cv_model_test.js (inatapi),
which export stats for how well the model performed on a sample of observations
assuming the Community Taxon is correct.

Usage:

  rails runner tools/export_vision_scores.rb
  rails runner tools/export_vision_scores.rb --sample-size 1000 --query "taxon_id=123&place_id=456"

where [options] are:
EOS
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :file, "Where to write output. Default will be STDOUT.", type: :string, short: "-f"
  opt :sample_size, "Number of observations to sample", type: :int, short: "-s", default: 100
  opt :query, "Observation search query to filter obs. Note that with_photos and order_by will be overridden",
    type: :string, short: "-q"
end

start = Time.now
num_scores = 0
num_obs = 0
page = 1
api_url = CONFIG.node_api_url.sub( "v1", "v2" )
if api_url =~ /staging/
  token = User.find(1).api_token
else
  token = JsonWebToken.applicationToken
end
api_url.sub!( /https:\/\/stagingapi.inaturalist.org/, "http://127.0.0.1:4000" )
api_url.sub!( /http:\/\/localhost/, "http://127.0.0.1" )
outpath = "vision-scores-#{Date.today}.csv"
csv = if OPTS.file
  CSV.open( OPTS.file, "w" )
else
  CSV( STDOUT )
end
csv << %w(
  observation_id
  photo_id
  photo_ext
  taxon_id
  position
  combined_score
  vision_score
  frequency_score
)
while true
  break if num_obs >= OPTS.sample_size
  obs = Observation.elastic_query( Rack::Utils.parse_nested_query( OPTS.query ).merge(
    with_photos: true,
    order_by: "random",
    per_page: 200,
    page: page,
    track_total_hits: true
  ) )
  break if obs.blank?
  puts "#{num_obs} / #{obs.total_entries} obs, #{num_scores} scores"
  obs.each do |o|
    next unless o.appropriate? # Remove copyright violations and the like
    url = "#{api_url}/computervision/score_observation/#{o.uuid}?fields=combined_score,vision_score,frequency_score"
    puts "getting #{url}" if OPTS.debug
    r = begin
      RestClient.get( url, Authorization: token )
    rescue RestClient::InternalServerError => e
      puts "ERROR getting #{url}: #{e}"
      next
    end
    json = JSON.parse( r.body )
    photo_url = UrlHelper.observation_image_url( o )
    photo_id = photo_url[/photos\/(\d+)/, 1].to_i
    photo_ext = photo_url[/square\.([A-z0-9]+)/, 1]
    json["results"].each_with_index do |r,i|
      csv << [
        o.id,
        photo_id,
        photo_ext,
        r["taxon"]["id"],
        i,
        r["combined_score"],
        r["vision_score"],
        r["frequency_score"]
      ]
      num_scores += 1
    end
    num_obs += 1
  end
  page += 1
end
csv.close
puts
puts "Wrote #{num_scores} scores from #{num_obs} obs in #{Time.now - start}s (#{num_obs / (Time.now - start)} obs/s)"
puts
