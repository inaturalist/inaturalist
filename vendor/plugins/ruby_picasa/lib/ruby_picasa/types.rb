module RubyPicasa
  # attributes :url, :height, :width
  class PhotoUrl < Objectify::ElementParser
    attributes :url, :height, :width
  end


  class ThumbnailUrl < PhotoUrl

    # The name of the current thumbnail. For possible names, see Photo#url
    def thumb_name
      name = url.scan(%r{/s([^/]+)/[^/]+$}).flatten.compact.first
      if name
        name.sub(/-/, '')
      end
    end
  end
  
  class Author < Objectify::Atom::Author
    namespaces :gphoto
    attribute :user, 'gphoto:user'
    attribute :nickname, 'gphoto:nickname'
  end

  # Note that in all defined classes I'm ignoring values I don't happen to need
  # or know about. Please do add support for the ones I've missed.  Be sure to
  # declare which namespaces are supported with the namespaces method.  Any
  # elements defined in other namespaces are automatically ignored.
  #
  # Base class for User, Photo and Album types, not used independently.
  #
  #   attribute :id, 'gphoto:id'
  #   attribute :feed_id, 'id'
  #   attributes :updated, :title
  #   
  #   has_many :links, Objectify::Atom::Link, 'link'
  #   has_one :content, PhotoUrl, 'media:content'
  #   has_many :thumbnails, ThumbnailUrl, 'media:thumbnail'
  #   has_one :author, Objectify::Atom::Author, 'author'
  class Base < Objectify::DocumentParser
    namespaces :openSearch, :gphoto, :media
    flatten 'media:group'

    attribute :id, 'gphoto:id'
    attribute :feed_id, 'id'
    attributes :updated, :title

    has_many :links, Objectify::Atom::Link, 'link'
    has_one :content, PhotoUrl, 'media:content'
    has_many :thumbnails, ThumbnailUrl, 'media:thumbnail'
    has_one :author, Author, 'author'

    # Return the link object with a matching rel attribute value. +rel+ can be
    # either a fully matching string or a regular expression.
    def link(rel)
      links.find { |l| rel === l.rel }
    end

    def session=(session)
      @session = session
    end

    # Should return the Picasa instance that retrieved this data.
    def session
      if @session
        @session
      else
        @session = parent.session if parent
      end
    end

    # Retrieves the data feed at the url of the current record.
    def feed(options = {})
      session.get_url(link('http://schemas.google.com/g/2005#feed').href, options)
    end

    # If the results are paginated, retrieve the next page.
    def next
      if link = link('next')
        session.get_url(link.href)
      end
    end

    # If the results are paginated, retrieve the previous page.
    def previous
      if link = link('previous')
        session.get_url(link.href)
      end
    end

    # Thumbnail names are by image width in pixels. Sizes up to 160 may be
    # either cropped (square) or uncropped:
    #
    #   cropped:        32c, 48c, 64c, 72c, 144c, 160c
    #   uncropped:      32u, 48u, 64u, 72u, 144u, 160u
    #
    # The rest of the image sizes should be specified by the desired width
    # alone. Widths up to 800px may be embedded on a webpage:
    # 
    #   embeddable:     200, 288, 320, 400, 512, 576, 640, 720, 800
    #   not embeddable: 912, 1024, 1152, 1280, 1440, 1600
    #
    # if a options is set to true or a hash is given, the width and height of
    # the image will be added to the hash and returned. Useful for passing to
    # the rails image_tag helper as follows:
    #
    #   image_tag(*image.url('72c', { :class => 'thumb' }))
    #   
    # which results in:
    #
    #   <img href="..." class="thumb" width="72" height="72">
    #
    def url(thumb_name = nil, options = nil)
      url = nil
      if thumb_name.is_a? Hash
        options = thumb_name
        thumb_name = nil
      end
      options = {} if options and not options.is_a? Hash
      if thumb_name
        if thumb = thumbnail(thumb_name)
          url = thumb.url
          options = { :width => thumb.width, :height => thumb.height }.merge(options) if options
        end
      else
        url = content.url
        options = { :width => content.width, :height => content.height }.merge(options) if options
      end
      if options
        [url, options]
      else
        url
      end
    end

    # See +url+ for possible image sizes
    def thumbnail(thumb_name)
      raise PicasaError, 'Invalid thumbnail size' unless Photo::VALID.include?(thumb_name.to_s)
      thumb = thumbnails.find { |t| t.thumb_name == thumb_name }
      if thumb
        thumb
      elsif session
        f = feed(:thumbsize => thumb_name)
        if f
          f.thumbnails.first
        end
      end
    end
  end


  # Includes attributes and associations defined on Base, plus:
  #
  #   attributes :total_results, # represents total number of albums
  #     :start_index,
  #     :items_per_page,
  #     :thumbnail,
  #     :user # userID
  #   has_many :entries, :Album, 'entry'
  class User < Base
    attribute :user, 'gphoto:user'
    attribute :nickname, 'gphoto:nickname'
    attributes :total_results, # represents total number of albums
      :start_index,
      :items_per_page,
      :thumbnail
    has_many :entries, :Album, 'entry'

    # The current page of albums associated to the user.
    def albums
      entries
    end
  end


  # Includes attributes and associations defined on Base and User, plus:
  #
  #   has_many :entries, :Photo, 'entry'
  class RecentPhotos < User
    has_many :entries, :Photo, 'entry'

    # The current page of recently updated photos associated to the user.
    def photos
      entries
    end

    undef albums
  end


  # Includes attributes and associations defined on Base, plus:
  #
  #   attributes :published,
  #     :summary,
  #     :rights,
  #     :name,
  #     :access,
  #     :numphotos, # number of pictures in this album
  #     :total_results, # number of pictures matching this 'search'
  #     :start_index,
  #     :items_per_page,
  #     :allow_downloads
  #   has_many :entries, :Photo, 'entry'
  class Album < Base
    attributes :published,
      :summary,
      :rights,
      :name,
      :access,
      :numphotos, # number of pictures in this album
    :total_results, # number of pictures matching this 'search'
    :start_index,
      :items_per_page,
      :allow_downloads
    has_many :entries, :Photo, 'entry'

    # True if this album's rights are set to public
    def public?
      rights == 'public'
    end

    # True if this album's rights are set to private
    def private?
      rights == 'private'
    end

    # The current page of photos in the album.
    def photos(options = {})
      if entries.blank? and !@photos_requested
        @photos_requested = true
        if session and data = feed
          self.entries = data.entries 
        else
          []
        end
      else
        entries
      end
    end
  end


  class Search < Album
    # The current page of photos matching the search.
    def photos(options = {})
      super
    end
  end

  # Includes attributes and associations defined on Base, plus:
  #
  #   attributes :published,
  #     :summary,
  #     :version, # can use to determine if need to update...
  #     :position,
  #     :albumid, # useful from the recently updated feed for instance.
  #     :width,
  #     :height,
  #     :description,
  #     :keywords,
  #     :credit
  #   attribute :unique_id, 'exif:imageUniqueID'
  #   attribute :exif_distance, 'exif:distance'
  #   attribute :exif_exposure, 'exif:exposure'
  #   attribute :exif_flash, 'exif:flash'
  #   attribute :exif_focallength, 'exif:focallength'
  #   attribute :exif_fstop, 'exif:fstop'
  #   attribute :exif_iso, 'exif:iso'
  #   attribute :exif_make, 'exif:make'
  #   attribute :exif_model, 'exif:model'
  #   attribute :exif_time, 'exif:time'
  #   has_one :author, Objectify::Atom::Author, 'author'
  class Photo < Base
    CROPPED = %w[ 32c 48c 64c 72c 104c 144c 150c 160c ]
    UNCROPPED = %w[ 104 110 128 144 150 160 200 220 288 320 32 400 48 512 576 640 64 720 72 800 912 94 1024 1152 1280 1440 1600 ]
    UNCROPPED += UNCROPPED.map {|s| "#{s}u"}
    MEDIUM = %w[ 200 288 320 400 512 576 640 720 800 ]
    LARGE = %w[ 912 1024 1152 1280 1440 1600 ]
    VALID = CROPPED + UNCROPPED + MEDIUM + LARGE

    class Point < Objectify::DocumentParser
      namespaces 'gml'
      attribute :pos, 'gml:pos'
      def lat
        @lat ||= pos.split(" ").first.to_f
      end

      def lng
        @lng ||= pos.split(" ").last.to_f
      end

      def coords
        [lat, lng]
      end
    end
    
    class License < Objectify::ElementParser
      attributes :id, :name, :url
    end

    namespaces 'exif', 'georss', 'gml', 'gphoto'

    attributes :published,
      :summary,
      :version, # can use to determine if need to update...
      :position,
      :albumid, # useful from the recently updated feed for instance.
      :width,
      :height,
      :description,
      :keywords,
      :credit

    flatten 'exif:tags'
    attribute :unique_id, 'exif:imageUniqueID'
    attribute :exif_distance, 'exif:distance'
    attribute :exif_exposure, 'exif:exposure'
    attribute :exif_flash, 'exif:flash'
    attribute :exif_focallength, 'exif:focallength'
    attribute :exif_fstop, 'exif:fstop'
    attribute :exif_iso, 'exif:iso'
    attribute :exif_make, 'exif:make'
    attribute :exif_model, 'exif:model'
    attribute :exif_time, 'exif:time'
    
    attribute :user, 'gphoto:user'
    attribute :nickname, 'gphoto:nickname'

    flatten 'georss:where'
    
    has_one :point, RubyPicasa::Photo::Point, 'gml:Point'
    has_one :author, Author, 'author'
    has_one :license, RubyPicasa::Photo::License, 'gphoto:license'

  end

end

