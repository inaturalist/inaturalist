# frozen_string_literal: true

require_relative "taxon_importer/taxon_importer"
require "optimist"

unless Rails.env.development?
  puts "Importing taxa is only supported in the development environment"
  exit 1
end

opts = Optimist.options do
  opt :taxon_id, "Taxon ID(s) from iNaturalist", type: :integers, short: "-i", required: true
end

opts.taxon_id.each do | id |
  puts "Importing taxon id: #{id}..."
  local_taxon_id = TaxonImporter.import taxon_id: id
  if local_taxon_id.positive?
    puts "Taxon imported as: #{local_taxon_id}"
  else
    puts "Failed to import taxon id: #{id}"
  end
  puts "\n"
end
