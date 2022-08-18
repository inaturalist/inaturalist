module DarwinCore
  class Descriptor < FakeView
    def initialize( options = {} )
      super()
      @core = options[:core] || DarwinCore::Cores::OCCURRENCE
      @extensions = options[:extensions] || []
      @ala = options[:ala]
      @template = options[:template] || File.join( "observations", "dwc_descriptor" )
    end

    def render
      super(
        template: @template,
        handlers: [:builder],
        formats: [:xml],
        assigns: {
          core: @core,
          extensions: @extensions
        }
      )
    end
  end
end
