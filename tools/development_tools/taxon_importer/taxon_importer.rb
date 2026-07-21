# frozen_string_literal: true

class TaxonImporter
  REQUESTED_FIELDS = %w(id name rank rank_level iconic_taxon_id is_active ancestry).freeze
  PRODUCTION_API_ENDPOINT = "https://api.inaturalist.org/v2"

  attr_reader :taxon_id

  class << self
    # @param [Integer] taxon_id Remote taxon ID
    # @return [Integer] taxon_id Locally created taxon ID
    def import( options = {} )
      taxon_id = options.delete( :taxon_id )
      new( taxon_id: taxon_id ).import( options )
    end
  end

  def initialize( taxon_id: )
    @taxon_id = taxon_id
  end

  # Import will 'De-Limpkinize'
  # Aramus guarauna (Limpkin) is the first sequential species in iNat at id#7,
  # therefore it's ancestry is built out sequentially from
  # Animalia(1) -> Chordata(2) -> ... -> Aramus guarauna(7)
  # Life was later added (48460) as the root
  #
  # Dynamic ancestry will track and translate PKs
  def import( options = {} )
    unless results.present?
      return options[:with_taxon] ? nil : 0
    end

    taxon_id = results.each_with_object( [] ) do | result, dynamic_ancestry |
      taxon = Taxon.find_or_initialize_by( name: result["name"], rank: result["rank"] )
      unless taxon.persisted?
        taxon.update(
          rank_level: result["rank_level"],
          iconic_taxon_id: dynamic_ancestry.reverse.find { _1.in? iconic_ids },
          is_active: result["is_active"],
          is_iconic: result["iconic_taxon_id"] == result["id"],
          ancestry: dynamic_ancestry.join( "/" )
        )
      end
      dynamic_ancestry << taxon.id
    end.last || 0
    return taxon_id unless options[:with_taxon]

    Taxon.find_by_id( taxon_id )
  end

  private

  def results
    unless ancestry_chain.present?
      @results ||= []
      return @results
    end

    api_response = INatAPIService.get(
      "/taxa/#{full_ids.join( ',' )}",
      { fields: REQUESTED_FIELDS },
      v2: true,
      endpoint: PRODUCTION_API_ENDPOINT
    )
    if api_response.blank?
      raise "Empty API response in `results` for `#{full_ids.join( ',' )}`"
    end

    @results ||= api_response.results
  end

  def ancestry_chain
    api_response = INatAPIService.get(
      "/taxa/#{taxon_id}",
      { fields: "ancestry" },
      v2: true,
      endpoint: PRODUCTION_API_ENDPOINT
    )
    if api_response.blank?
      raise "Empty API response in `ancestry_chain` for `#{taxon_id}`"
    end

    @ancestry_chain ||= api_response.results.first&.dig( "ancestry" ) || ""
  end

  def full_ids
    ancestry_chain.split( "/" ) + [taxon_id]
  end

  def iconic_ids
    @iconic_ids ||= Taxon.where( is_iconic: true ).pluck :id
  end
end
