module DarwinCore
  class Metadata < FakeView
    def initialize(options = {})
      super()
      @observations_params = options[:observations_params] || {}
      site = options[:site] || Site.find_by_id( options[:site_id] ) || Site.default
      @contact = site.contact || {}
      @creator = @contact || {}
      @metadata_provider = @contact || {}
      scope = Observation.query( @observations_params )
      if options[:extensions] && 
          (options[:extensions].include?("EolMedia") || options[:extensions].include?("SimpleMultimedia"))
        scope = scope.has_photos
      end
      @extent     = scope.calculate(:extent, :geom)
      @start_date = scope.minimum(:observed_on)
      @end_date   = scope.maximum(:observed_on)
      @license    = options[:license]
      @uri        = FakeView.observations_url( @observations_params )
      @taxon      = Taxon.find_by_id( @observations_params[:taxon_id] )
      @place      = Place.find_by_id( @observations_params[:place_id] )
      @freq       = options[:freq]
    end
  end
end
