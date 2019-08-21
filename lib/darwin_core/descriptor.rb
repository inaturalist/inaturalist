module DarwinCore
  class Descriptor < FakeView
    def initialize(options = {})
      super()
      @core = options[:core]
      @extensions = options[:extensions]
      @ala = options[:ala]
    end
  end
end
