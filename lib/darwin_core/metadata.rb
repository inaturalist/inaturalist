module DarwinCore
  class Metadata < FakeView
    def initialize(options = {})
      super()
      @observations_params = options[:observations_params] || {}
      site = options[:site] || ::Site.find_by_id( options[:site_id] ) || ::Site.default
      @contact = site.contact || {}
      @creator = @contact || {}
      @metadata_provider = @contact || {}
      if options[:core] == DarwinCore::Cores::OCCURRENCE
        es_response = Observation.elastic_search( Observation.params_to_elastic_query( @observations_params ).merge( {
          aggs: {
            bbox: {
              geo_bounds: {
                field: "location"
              }
            },
            start_date: {
              min: {
                field: "observed_on"
              }
            },
            end_date: {
              max: {
                field: "observed_on"
              }
            }
          }
        } ) )
        if es_response.aggregations.start_date && es_response.aggregations.start_date.value_as_string
          @start_date = Date.parse( es_response.aggregations.start_date.value_as_string )
        end
        if es_response.aggregations.end_date && es_response.aggregations.end_date.value_as_string
          @end_date = Date.parse( es_response.aggregations.end_date.value_as_string )
        end
        @extent     = es_response.aggregations.bbox.bounds if es_response.aggregations.bbox
        @uri        = ::FakeView.observations_url( @observations_params )
        @taxa       = ::Taxon.where( id: @observations_params[:taxon_ids] ).limit( 200 ).all
        @place      = ::Place.find_by_id( @observations_params[:place_id] )
      else
        @uri        = ::FakeView.taxa_url
      end
      @license    = options[:license]
      @taxonomy   = ::Taxon.where( id: @taxa.map{|t| t.self_and_ancestor_ids}.flatten.uniq.compact ).arrange if @taxa
      @freq       = options[:freq]
    end
  end
end
