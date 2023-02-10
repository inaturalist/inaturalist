# frozen_string_literal: true

if Rails.env.production?
  puts "This script is for setting up a dev environment only."
  exit( 0 )
end

def create_controlled_term_from_json( ct_json )
  puts "Importing #{ct_json[:label]}..."
  controlled_term = ControlledTerm.find_by_uuid( ct_json[:uuid] )
  controlled_term ||= ControlledTerm.
    where( is_value: ct_json[:is_value] ).
    joins( :labels ).
    where( "controlled_term_labels.label = ?", ct_json[:label] ).
    first
  controlled_term ||= ControlledTerm.create(
    active: true,
    blocking: ct_json[:blocking],
    is_value: ct_json[:is_value],
    multivalued: ct_json[:multivalued],
    ontology_uri: ct_json[:ontology_uri],
    uri: ct_json[:uri],
    uuid: ct_json[:uuid]
  )
  unless controlled_term.labels.where( label: ct_json[:label] ).exists?
    controlled_term.labels << ControlledTermLabel.new( label: ct_json[:label] )
  end
  combined_taxon_ids = [ct_json[:taxon_ids], ct_json[:excepted_taxon_ids]].flatten.compact.uniq
  remote_taxa = JSON.parse(
    RestClient.get(
      "https://api.inaturalist.org/v2/taxa/#{combined_taxon_ids.join( ',' )}?fields=id,name,rank"
    ).body,
    symbolize_names: true
  )[:results].each_with_object( {} ) do | taxon_json, memo |
    taxon = Taxon.where( name: taxon_json[:name], rank: taxon_json[:rank] ).first
    taxon ||= Taxon.import( taxon_json[:name] )
    taxon ||= Taxon.create( name: taxon_json[:name], rank: taxon_json[:rank] )
    memo[taxon_json[:id]] = taxon
  end
  ( ct_json[:taxon_ids] || [] ).each do | taxon_id |
    taxon = remote_taxa[taxon_id]
    next if controlled_term.controlled_term_taxa.where( taxon_id: taxon.id ).exists?

    controlled_term.controlled_term_taxa << ControlledTermTaxon.new(
      taxon: taxon,
      controlled_term: controlled_term,
      exception: false
    )
  end
  ( ct_json[:excepted_taxon_ids] || [] ).each do | taxon_id |
    taxon = remote_taxa[taxon_id]
    next if controlled_term.controlled_term_taxa.where( taxon_id: taxon.id ).exists?

    controlled_term.controlled_term_taxa << ControlledTermTaxon.new(
      taxon: taxon,
      controlled_term: controlled_term,
      exception: true
    )
  end
  puts "Imported #{controlled_term}"
  controlled_term
end

response = RestClient.get( "https://api.inaturalist.org/v2/controlled_terms?fields=all" )
json = JSON.parse( response.body, symbolize_names: true )
json[:results].each do | ct_json |
  attr_ct = create_controlled_term_from_json( ct_json )
  ct_json[:values].each do | ct_value_json |
    value_ct = create_controlled_term_from_json( ct_value_json )
    begin
      ControlledTermValue.create!( controlled_attribute: attr_ct, controlled_value: value_ct )
    rescue ActiveRecord::RecordInvalid => e
      # Ok if association already exists
      raise e unless e.message =~ /taken/
    end
  end
end
