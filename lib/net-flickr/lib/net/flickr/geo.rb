module Net; class Flickr; class Photo

  # A Flickr photo tag.
  # 
  # Don't instantiate this class yourself.
  class Geo
  
    #attr_reader :id, :author, :raw, :name
    
    def initialize(photo)
      @photo = photo
      
      #@id          = geo_xml['id']
      # @author      = tag_xml['author']
      # @raw         = tag_xml['raw']
      # @name        = tag_xml.inner_text
      # @machine_tag = tax_xml['machine_tag'] == '1'
      @response  = nil
      @latitude  = nil
      @longitude = nil
      @accuracy  = nil
    end
    
    def get_location
      return @response unless @response.nil?
      @response = Net::Flickr.instance().request('flickr.photos.geo.getLocation',
                                                 'photo_id' => @photo.id)
    end
    
    def latitude
      get_location.at('location')[:latitude].to_f
    end
    
    def longitude
      get_location.at('location')[:longitude].to_f
    end
    
    def accuracy
      get_location.at('location')[:accuracy].to_i
    end
    
    alias :location :get_location
  
  end

end; end; end
