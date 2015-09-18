module DarwinCore
  class Descriptor < FakeView
    def initialize(options = {})
      super()
      @core = options[:core]
      @extensions = options[:extensions]
    end
  end
end
