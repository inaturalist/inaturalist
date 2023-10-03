require "rubygems"
require "optimist"

OPTS = Optimist::options do
    banner <<-EOS

Import geo model evaluation data for taxa in the geo model.

Usage:

  rails runner tools/load_geo_model_taxa.rb

where [options] are:
EOS
  opt :thresholds_path, "Path to the thresholds file.", type: :string, short: "-t"
  opt :eval_path, "Path to the evaluation data file.", type: :string, short: "-v"
end


unless OPTS.thresholds_path
  puts "You must specify a thresholds path"
  exit(0)
end

unless OPTS.eval_path
  puts "You must specify an evaluation data path"
  exit(0)
end

ActiveRecord::Base.connection.execute( "TRUNCATE TABLE geo_model_taxa RESTART IDENTITY" )

taxon_thresholds = {}
CSV.foreach( OPTS.thresholds_path, headers: true ) do |row|
  taxon_thresholds[row["taxon_id"].to_i] = row["thres"].to_f
end

taxon_eval_data = {}
CSV.foreach( OPTS.eval_path, headers: true ) do |row|
  taxon_eval_data[row["taxon_id"].to_i] = {
    taxon_id: row["taxon_id"],
    prauc: row["prauc"],
    precision: row["p"],
    recall: row["r"],
    f1: row["f1"]
  }
end

GeoModelTaxon.transaction do
  taxon_thresholds.keys.map(&:to_i).each do |taxon_id|
    if !taxon_thresholds[taxon_id]
      puts "#{taxon_id} has no threshold"
    elsif !taxon_thresholds[taxon_id].is_a?( Float )
      puts "#{taxon_id} threshold is not a Float: #{taxon_thresholds[taxon_id]}"
    end
    geo_model_attributes = {
      taxon_id: taxon_id,
      threshold: taxon_thresholds[taxon_id]
    }
    if taxon_eval_data[taxon_id]
      geo_model_attributes.merge!( taxon_eval_data[taxon_id] )
    end
    GeoModelTaxon.create( geo_model_attributes )
  end
end
