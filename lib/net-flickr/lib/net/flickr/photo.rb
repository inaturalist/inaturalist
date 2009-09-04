#--
# Copyright (c) 2007-2008 Ryan Grove <ryan@wonko.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#   * Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright notice,
#     this list of conditions and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
#   * Neither the name of this project nor the names of its contributors may be
#     used to endorse or promote products derived from this software without
#     specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#++

module Net; class Flickr

  # A Flickr photo.
  # 
  # Don't instantiate this class yourself. Use the methods in Flickr::Photos to
  # retrieve photos from Flickr.
  class Photo
    SIZE_SUFFIX = {
      :square   => 's',
      :thumb    => 't',
      :small    => 'm',
      :medium   => nil,
      :large    => 'b',
      :original => 'o'
    }
  
    #--
    # Public Instance Methods
    #++
    
    attr_reader :id, :secret, :server, :farm, :photo_xml
    
    def initialize(photo_xml)
      raise AuthorizationError if Net::Flickr.instance().api_key.nil?
      
      if photo_xml.is_a?(Hpricot::Elem) || photo_xml.is_a?(String)
        parse_xml(photo_xml)
      elsif photo_xml.is_a?(Integer)
        @id = photo_xml
      end
      
      # Save the original photo_xml Hpricot object
      @photo_xml = photo_xml
      
      # Detailed photo info.
      @context_xml = nil
      @info_xml    = nil
    end
    
    # Call and retreive comments
    def comments
      raise NotImplementedError
    end
    
    # Check to see if there are comments for the photo
    def comments?
      info_xml = get_info
      return info_xml.at('comments').inner_text.to_i > 0
    end
    
    # Deletes this photo from Flickr. This method requires authentication with
    # +delete+ permission.
    def delete
      Net::Flickr.instance().photos.delete(@id)
    end
    
    # Gets this photo's description.
    def description
      info_xml = get_info
      return info_xml.at('description').inner_text
    end
    
    # Sets this photo's description. This method requires authentication with
    # +write+ permission.
    def description=(value)
      set_meta(@title, value)
    end
    
    # flickr.photos.getExif
    def exif
      raise NotImplementedError
    end
    
    # Whether or not this photo is visible to family.
    def family?
      get_info if @is_family.nil?
      return @is_family || @is_public
    end

    # flickr.photos.getFavorites
    def favorites
      raise NotImplementedError
    end
    
    # Whether or not this photo is visible to friends.
    def friend?
      get_info if @is_friend.nil?
      return @is_friend || @is_public
    end
    
    def geo
      @geo ||= Net::Flickr::Photo::Geo.new(self)
    end
    
    # flickr.photos.getExif
    def gps
      raise NotImplementedError
    end
    
    # Gets the time this photo was last modified.
    def modified
      info_xml = get_info
      return Time.at(info_xml.at('dates')[:lastupdate].to_i)
    end
    
    # Gets the next photo in the owner's photo stream, or +nil+ if this is the
    # last photo in the stream.
    def next
      context_xml = get_context
      next_xml    = context_xml.at('nextphoto')
      
      return Photo.new(next_xml) if next_xml[:id] != '0'
      return nil
    end
    
    # Gets the user id of this photo's owner.
    def owner
      @owner[:nsid]
    end
    
    # Gets the URL of this photo's Flickr photo page.
    def page_url
      return "http://www.flickr.com/photos/#{@owner[:nsid]}/#{@id}"
    end
    
    # flickr.photos.getAllContexts
    def pools
      raise NotImplementedError
    end
    
    # Gets the time this photo was posted to Flickr.
    def posted
      info_xml = get_info
      return Time.at(info_xml.at('dates')[:posted].to_i)
    end
    
    # flickr.photos.setDates
    def posted=(time)
    end
    
    # Gets the previous photo in the owner's photo stream, or +nil+ if this is
    # the first photo in the stream.
    def previous
      context_xml = get_context
      prev_xml = context_xml.at('prevphoto')
      
      return Photo.new(prev_xml) if prev_xml[:id] != '0'
      return nil
    end

    alias :prev :previous
    
    # Whether or not this photo is visible to the general public.
    def public?
      get_info if @is_public.nil?
      return @is_public
    end
    
    # flickr.photos.getAllContexts
    def sets
      raise NotImplementedError
    end
    
    # flickr.photos.getSizes
    def sizes
      raise NotImplementedError
    end
    
    # Gets the source URL for this photo at one of the following specified
    # sizes. Returns +nil+ if the specified _size_ is not available.
    # 
    # [:square]   75x75px
    # [:thumb]    100px on longest side
    # [:small]    240px on longest side
    # [:medium]   500px on longest side
    # [:large]    1024px on longest side (not available for all images)
    # [:original] original image in original file format
    def source_url(size = :medium)
      suffix = SIZE_SUFFIX[size]
      
      case size
        when :medium
          return "http://farm#{@farm}.static.flickr.com/#{@server}/#{@id}_" +
              "#{@secret}.jpg"
        
        when :original
          info_xml = get_info
          
          original_secret = info_xml[:originalsecret]
          original_format = info_xml[:originalformat]
          
          return nil if original_secret.nil? || original_format.nil? 
          return "http://farm#{@farm}.static.flickr.com/#{@server}/#{@id}_" +
              "#{original_secret}_o.#{original_format}"

        else
          return "http://farm#{@farm}.static.flickr.com/#{@server}/#{@id}_" +
              "#{@secret}_#{suffix}.jpg"
      end
    end
    
    # get the tags
    def tags
      tags = {}
      get_info.search('//tag').each do |tag|
        tags[tag.inner_html] = Net::Flickr::Tag.new(tag)
      end
      tags
    end
    
    # Gets the time this photo was taken.
    def taken
      info_xml = get_info
      return Time.parse(info_xml.at('dates')[:taken])
    end
    
    # flickr.photos.setDates
    def taken=(time)
      raise NotImplementedError
    end
    
    # flickr.photos.getExif
    def tiff
      raise NotImplementedError
    end
    
    # Gets this photo's title.
    def title
      info_xml = get_info
      return info_xml.at('title').inner_text
    end
    
    # Sets this photo's title. This method requires authentication with +write+
    # permission.
    def title=(value)
      set_meta(value, description)
    end
    
    #--
    # Private Instance Methods
    #++
    
    private
    
    # Gets context information for this photo.
    def get_context
      @context_xml ||= Net::Flickr.instance().request('flickr.photos.getContext',
          :photo_id => @id)
    end
    
    # Gets detailed information for this photo.
    def get_info
      return @info_xml unless @info_xml.nil?

      response = Net::Flickr.instance().request('flickr.photos.getInfo', :photo_id => @id, 
          :secret => @secret)
      
      @info_xml = response.at('photo')

      if @is_family.nil? || @is_friend.nil? || @is_public.nil?
        @is_family = @info_xml.at('visibility')[:isfamily] == '1'
        @is_friend = @info_xml.at('visibility')[:isfriend] == '1'
        @is_public = @info_xml.at('visibility')[:ispublic] == '1'
      end
      
      return @info_xml
    end
    
    # Parse a photo xml chunk.
    def parse_xml(photo_xml)
      # Convert photo_xml to an Hpricot::Elem if it isn't one already.
      unless photo_xml.is_a?(Hpricot::Elem)
        photo_xml = Hpricot::XML(photo_xml)
      end
      
      # Figure out what format we're dealing with, since someone at Flickr
      # thought it would be fun to be inconsistent (thanks, whoever you are).
      if photo_xml[:owner] && photo_xml[:ispublic]
        # This is a basic XML chunk.
        @id        = photo_xml[:id]
        @owner     = photo_xml[:owner]
        @secret    = photo_xml[:secret]
        @server    = photo_xml[:server]
        @farm      = photo_xml[:farm]
        @title     = photo_xml[:title]
        @is_public = photo_xml[:ispublic] == '1'
        @is_friend = photo_xml[:isfriend] == '1'
        @is_family = photo_xml[:isfamily] == '1'
      
      elsif photo_xml[:url] && photo_xml[:thumb]
        # This is a context XML chunk. It doesn't include visibility info.
        @id        = photo_xml[:id]
        @secret    = photo_xml[:secret]
        @server    = photo_xml[:server]
        @farm      = photo_xml[:farm]
        @title     = photo_xml[:title]
        @is_public = nil
        @is_friend = nil
        @is_family = nil  
      
      elsif photo_xml[:secret] && photo_xml.at('owner[@nsid]')
        # This is a detailed XML chunk (probably from flickr.photos.getInfo).
        @id        = photo_xml[:id]
        @owner     = photo_xml.at('owner[@nsid]')
        @secret    = photo_xml[:secret]
        @server    = photo_xml[:server]
        @farm      = photo_xml[:farm]
        @is_public = photo_xml.at('visibility')[:ispublic] == '1'
        @is_friend = photo_xml.at('visibility')[:isfriend] == '1'
        @is_family = photo_xml.at('visibility')[:isfamily] == '1'
        @info_xml  = photo_xml
      end
    end
    
    # Sets date information for this photo.
    def set_dates(posted, taken, granularity = 0, args = {})
      raise NotImplementedError
    end
    
    # Sets meta information for this photo.
    def set_meta(title, description, args = {})
      args[:photo_id]    = @id
      args[:title]       = title
      args[:description] = description
      
      Net::Flickr.instance().request('flickr.photos.setMeta', args)
      
      @info_xml = nil
    end
  
  end

end; end
