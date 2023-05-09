# frozen_string_literal: true

module DarwinCore
  class Metadata
    def initialize( options = {} )
      super()
      @template = options[:template] || if @opts[:core] == DarwinCore::Cores::OCCURRENCE
        File.join( "observations", "dwc" )
      else
        File.join( "taxa", "dwc" )
      end
      @observations_params = options[:observations_params] || {}
      site = options[:site] || ::Site.find_by_id( options[:site_id] ) || ::Site.default
      @contact = site.contact || {}
      @creator = site.dwc_creator || {}
      # iNat staff are always the party responsible for constructing the
      # metadata of any archive iNat creates
      @metadata_provider = Site.default.contact
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
        if ( start_date_string = es_response.aggregations.start_date&.value_as_string )
          @start_date = Date.parse( start_date_string )
        end
        if ( end_date_string = es_response.aggregations.end_date&.value_as_string )
          @end_date = Date.parse( end_date_string )
        end
        @extent     = es_response.aggregations.bbox.bounds if es_response.aggregations.bbox
        @uri        = ::FakeView.observations_url( @observations_params )
        @taxa       = ::Taxon.where( id: @observations_params[:taxon_ids] ).limit( 200 ).all
        @place      = ::Place.find_by_id( @observations_params[:place_id] )
      else
        @uri        = ::FakeView.taxa_url
      end
      @license = options[:license]
      if @taxa
        @taxonomy = ::Taxon.where( id: @taxa.map( &:self_and_ancestor_ids ).flatten.uniq.compact ).arrange
      end
      @freq = options[:freq]
    end

    def render
      # puts "instance_variables: #{instance_variables}"
      FakeView.render(
        layout: nil,
        template: @template,
        handlers: [:erb],
        formats: [:eml],
        assigns: {
          contact: @contact,
          creator: @creator,
          end_date: @end_date,
          extent: @extent,
          freq: @freq,
          license: @license,
          metadata_provider: @metadata_provider,
          observations_params: @observations_params,
          place: @place,
          start_date: @start_date,
          taxa: @taxa,
          uri: @uri
        }
      )
    end
  end
end
