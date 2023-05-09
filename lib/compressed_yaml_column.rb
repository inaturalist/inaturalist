class CompressedYAMLColumn < Hash
  class << self
    def dump( obj )
      return if obj.nil?
      Zlib::Deflate.deflate( YAML.dump( obj ) )
    end

    def load( compressed_yaml )
      return if compressed_yaml.blank?
      return YAML.load( Zlib::Inflate.inflate( compressed_yaml ) )
    end
  end
end
