module DarwinCore
  class Descriptor < FakeView
    def initialize( options = {} )
      super()
      @core = options[:core] || DarwinCore::Cores::OCCURRENCE
      @extensions = options[:extensions] || []
      @ala = options[:ala]
      @include_uuid = options[:include_uuid]
      @include_county = options[:include_county]
      @include_public_coordinates = options[:include_public_coordinates]
      @template = options[:template] || File.join( "observations", "dwc_descriptor" )
    end

    def render
      super(
        template: @template,
        handlers: [:builder],
        formats: [:xml],
        assigns: {
          core: @core,
          extensions: @extensions,
          ala: @ala,
          include_uuid: @include_uuid,
          include_county: @include_county,
          include_public_coordinates: @include_public_coordinates,
        }
      )
    end
  end
end
