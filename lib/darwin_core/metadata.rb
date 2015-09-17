module DarwinCore
  class Metadata < FakeView
    def initialize(options = {})
      super()
      @contact = CONFIG.contact || {}
      @creator = CONFIG.creator || @contact || {}
      @metadata_provider = CONFIG.metadata_provider || @contact || {}
      scope = Observation.all
      if options[:quality] == "research"
        scope = scope.has_quality_grade(Observation::RESEARCH_GRADE)
      elsif options[:quality] == "casual"
        scope = scope.has_quality_grade(Observation::CASUAL_GRADE)
      end
      scope = scope.license('any')
      if options[:extensions] && 
          (options[:extensions].include?("EolMedia") || options[:extensions].include?("SimpleMultimedia"))
        scope = scope.has_photos
      end
      @extent     = scope.calculate(:extent, :geom)
      @start_date = scope.minimum(:observed_on)
      @end_date   = scope.maximum(:observed_on)
    end
  end
end
