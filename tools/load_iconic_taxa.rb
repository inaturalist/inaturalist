# frozen_string_literal: true

require_relative "development_tools/taxon_importer/taxon_importer"

#
# Creates taxa and names for all the iconic taxa.  This is to get a blank db
# up to speed.
#
# Run this with script/runner!
#

if Taxon::LIFE
  puts "Life exists (yay), skipping..."
else
  puts "Adding Life"
  life = Taxon.create(
    name: "Life",
    rank: "stateofmatter",
    source: Source.find_by_title( "iNaturalist" )
  )
  life.iconic_taxon = life
  life.save
end

taxa_res = begin
  try_and_try_again( [RestClient::TooManyRequests], exponential_backoff: true, sleep: 3 ) do
    RestClient.get( "https://api.inaturalist.org/v2/taxa?iconic=true&fields=id,name,rank" )
  end
rescue Socket::ResolutionError, RestClient::Exception, Timeout::Error
  puts "Failed to fetch iconic taxa from iNat. Try again later."
  exit 0
end
taxa = JSON.parse( taxa_res.body )["results"]

taxa.each do | api_taxon |
  if Taxon.where( name: api_taxon["name"], rank: api_taxon["rank"] ).exists?
    puts "#{api_taxon['rank'].capitalize} #{api_taxon['name']} exists, skipping..."
    next
  end

  local_taxon_id = TaxonImporter.import( taxon_id: api_taxon["id"] )
  if local_taxon_id.positive?
    taxon = Taxon.find( local_taxon_id )
    puts "Imported #{taxon}"
  else
    puts "Failed to import #{api_taxon['name']}"
  end
end
