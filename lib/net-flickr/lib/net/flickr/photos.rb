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

  # Provides methods for retrieving and/or manipulating one or more Flickr
  # photos.
  # 
  # Don't instantiate this class yourself. Instead, create an instance of the
  # +Flickr+ class and then use <tt>Flickr.photos</tt> to access this class,
  # like so:
  # 
  #   require 'net/flickr'
  #   
  #   flickr = Net::Flickr.new('524266cbd9d3c2xa2679fee8b337fip2')
  #   
  #   flickr.photos.recent.each do |photo|
  #     puts photo.title
  #   end
  #
  class Photos    
    # Missing methods
    # flickr.photos.getAllContexts
    # flickr.photos.getFavorites
    # flickr.photos.getNotInSet
    # flickr.photos.getPerms
    # flickr.photos.getRecent
    # flickr.photos.getSizes
    # flickr.photos.getUntagged
    # flickr.photos.removeTag
    # flickr.photos.search
    # flickr.photos.setContentType
    # flickr.photos.setDates
    # flickr.photos.setMeta
    # flickr.photos.setPerms
    # flickr.photos.setSafetyLevel
    # flickr.photos.setTags
    
    # Add tags to a photo. Requires +write+ permissions.
    # Returns true or raises exception
    #
    # See http://www.flickr.com/services/api/flickr.photos.addTags.html
    # for details
    def add_tags(photo_id, tags)
      Net::Flickr.instance().request('flickr.photos.addTags',
                                     { 'photo_id' => photo_id,
                                       'tags'     => tags })
      true
    end
    
    # Deletes the specified photo from Flickr. This method requires
    # authentication with +write+ permission.
    # 
    # See http://flickr.com/services/api/flickr.photos.delete.html for details.
    def delete(photo_id)
      Net::Flickr.instance().request('flickr.photos.delete',
                                     'photo_id' => photo_id)
      true
    end
    
    # Gets a list of all the sets and pools (context) a photo is found in
    #
    # See http://www.flickr.com/services/api/flickr.photos.getAllContexts.html
    # for more details.
    def get_all_contexts(photo_id)
      Net::Flickr.instance().request('flickr.photos.getAllContexts',
                                     'photo_id' => photo_id)
    end

    # Gets a list of recent photos from the calling user's contacts. This method
    # requires authentication with +read+ permission.
    # 
    # See http://flickr.com/services/api/flickr.photos.getContactsPhotos.html
    # for details.
    def get_contacts_photos(args = {})
      response = Net::Flickr.instance().request('flickr.photos.getContactsPhotos', args)
      photos = []
      
      response.search('photos/photo').each do |photo_xml|
        photos << Photo.new(photo_xml)
      end
      
      photos
    end
    
    alias :contacts :get_contacts_photos
    
    # Gets a list of recent public photos from the specified user's contacts.
    # 
    # See http://flickr.com/services/api/flickr.photos.getContactsPublicPhotos.html
    # for details.
    def get_contacts_public_photos(user_id, args = {})
      args['user_id'] = user_id
      response = Net::Flickr.instance().request('flickr.photos.getContactsPublicPhotos', args)
      photos = []
      
      response.search('photos/photo').each do |photo_xml|
        photos << Photo.new(photo_xml)
      end
      
      photos
    end
    
    alias :contacts_public :get_contacts_public_photos
    
    # Gets the next and previous photos in a photostream given a photo_id
    #
    # See http://www.flickr.com/services/api/flickr.photos.getContext.html
    # for details.
    def get_context(photo_id)
      response = Net::Flickr.instance().request('flickr.photos.getContext',
                                                'photo_id' => photo_id)
      previous_photo = response.at('prevphoto')
      next_photo     = response.at('nextphoto')
      photos = {}
      unless previous_photo[:id] == '0'
        photos['previous'] = Net::Flickr::Photo.new(previous_photo[:id].to_i)
      else
        photos['previous'] = nil
      end
      
      unless next_photo[:id] == '0'
        photos['next'] = Net::Flickr::Photo.new(next_photo[:id].to_i)
      else
        photos['next'] = nil
      end
      photos
    end
    
    # Gets a list of photo counts for the given date ranges for the calling
    # user. The list of photo counts is returned as an XML chunk. This method
    # requires authentication with +read+ permission.
    # 
    # See http://flickr.com/services/api/flickr.photos.getCounts.html for
    # details.
    def get_counts(args = {})
      Net::Flickr.instance().request('flickr.photos.getCounts', args).at('photocounts')
    end
    
    alias :counts :get_counts
    
    # Get any EXIF data applied to a photo and for now return the Hpricot
    # element
    #
    # See http://www.flickr.com/services/api/flickr.photos.getExif.html
    # for details
    def get_exif(photo_id, secret = nil)
      args = {}
      args['photo_id'] = photo_id
      args['secret'] = secret unless secret.nil?
      resp = Net::Flickr.instance().request('flickr.photos.getExif', args).at('photo')
      return nil if resp.empty?
      resp
    end
    
    def get_info(photo_id)
      resp = Net::Flickr.instance().request('flickr.photos.getInfo', 'photo_id' => photo_id)
      Photo.new(resp.at('photo'))
    end
    
    # Gets a list of the calling user's geotagged photos. This method requires
    # authentication with +read+ permission.
    # 
    # See http://flickr.com/services/api/flickr.photos.getWithGeoData.html for
    # details.
    def get_with_geo_data(args = {})
      PhotoList.new('flickr.photos.getWithGeoData', args)
    end
    
    alias :geotagged :get_with_geo_data
    
    # Gets a list of the calling user's photos that have not been geotagged.
    # This method requires authentication with +read+ permission.
    # 
    # See http://flickr.com/services/api/flickr.photos.getWithoutGeoData.html
    # for details.
    def get_without_geo_data(args = {})
      PhotoList.new('flickr.photos.getWithoutGeoData', args)
    end
    
    alias :not_geotagged :get_without_geo_data

    # Gets a list of the calling user's photos that are not included in any
    # sets. This method requires authentication with +read+ permission.
    # 
    # See http://flickr.com/services/api/flickr.photos.getNotInSet.html for
    # details.
    def get_not_in_set(args = {})
      PhotoList.new('flickr.photos.getNotInSet', args)
    end
    
    alias :not_in_set :get_not_in_set
    
    # Gets a list of the latest public photos uploaded to Flickr.
    # 
    # See http://flickr.com/services/api/flickr.photos.getRecent.html for
    # details.
    def get_recent(args = {})
      PhotoList.new('flickr.photos.getRecent', args)
    end
    
    alias :recent :get_recent
    
    # Gets a list of the calling user's photos that have been created or
    # modified since the specified _min_date_. This method requires
    # authentication with +read+ permission.
    # 
    # _min_date_ may be either an instance of Time or an integer representing a
    # Unix timestamp.
    # 
    # See http://flickr.com/services/api/flickr.photos.recentlyUpdated.html for
    # details.
    def recently_updated(min_date, args = {})
      args['min_date'] = min_date.to_i
      PhotoList.new('flickr.photos.recentlyUpdated', args)
    end
    
    # Gets a list of photos matching the specified criteria. Only photos visible
    # to the calling user will be returned. To return private or semi-private
    # photos, the caller must be authenticated with +read+ permission and have
    # permission to view the photos. Unauthenticated calls will return only
    # public photos.
    # 
    # See http://flickr.com/services/api/flickr.photos.search.html for details.
    # 
    # Note: Flickr doesn't allow parameterless searches, so be sure to specify
    # at least one search parameter.
    def search(args = {})
      PhotoList.new('flickr.photos.search', args)
    end
    
    # Gets a list of the calling user's photos that have no tags. This method
    # requires authentication with +read+ permission.
    # 
    # See http://flickr.com/services/api/flickr.photos.getUntagged.html for
    # details.
    def get_untagged(args = {})
      PhotoList.new('flickr.photos.getUntagged', args)
    end
    
    alias :untagged :get_untagged 
    
    # Gets a list of public photos for the specified _user_id_.
    # 
    # See http://flickr.com/services/api/flickr.people.getPublicPhotos.html for
    # details.
    def get_public_photos(user_id, args = {})
      args['user_id'] = user_id
      PhotoList.new('flickr.people.getPublicPhotos', args)
    end
    
    alias :user :get_public_photos 
    
  end

end; end
