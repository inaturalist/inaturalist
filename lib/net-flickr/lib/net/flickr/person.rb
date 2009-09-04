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

  class Person
    
    attr_reader :id, :username
    
    def initialize(person_xml)
      @id     = person_xml['nsid']
      @infoxml= nil
      
      if person_xml.at('username').nil? # this is a contact
        @username = person_xml['username']
      else # this is a call to a people function
        @username = person_xml.at('username').inner_text
      end
    end
    
    #--
    # Public Instance Methods
    #++
    
    # +true+ if this person is a Flickr admin, +false+ otherwise.
    def admin?
      infoxml = get_info
      return infoxml['isadmin'] == '1'
    end
    
    # +true+ if this person is a contact of the calling user, +false+ otherwise.
    # This method requires authentication with +read+ permission. In all other
    # cases, it returns +false+.
    def contact?
      infoxml = get_info
      
      if contact = infoxml['contact']
        return contact == '1'
      end
      
      return false
    end
    
    # see flickr.contacts.getPublicList
    def contacts(args = {})
      args['user_id'] = @id
      Net::Flickr.instance().contacts.get_public_list(args)
    end
    
    # +true+ if this person is a family member of the calling user, +false+
    # otherwise. This method requires authentication with +read+ permission. In
    # all other cases, it returns +false+.
    def family?
      infoxml = get_info
      
      if family = infoxml['family']
        return family == '1'
      end
      
      return false
    end
    
    # +true+ if this person is a friend of the calling user, +false+ otherwise.
    # This method requires authentication with +read+ permission. In all other
    # cases, it returns +false+.
    def friend?
      infoxml = get_info
      
      if friend = infoxml['friend']
        return friend == '1'
      end
      
      return false
    end
    
    # Gets this person's gender (e.g., 'M'). This method requires authentication
    # with +read+ permission and only returns information for contacts of the
    # calling user. In all other cases, it returns +nil+.
    def gender
      infoxml = get_info      
      return infoxml['gender']
    end
    
    # TODO: Implement Flickr.person.groups
    def groups
    end
    
    # Gets the URL of this person's buddy icon.
    def icon_url
      infoxml = get_info
      
      icon_server = infoxml['iconserver']
      icon_farm   = infoxml['iconfarm']
      
      if icon_server.to_i <= 0
        return 'http://www.flickr.com/images/buddyicon.jpg'
      else
        return "http://farm#{icon_farm}.static.flickr.com/#{icon_server}/buddyicons/#{@id}.jpg"
      end
    end
    
    # +true+ if this person is an ignored contact of the calling user, +false+
    # otherwise. This method requires authentication with +read+ permission and
    # only returns information for contacts of the calling user. In all other
    # cases, it returns +false+.
    def ignored?
      infoxml = get_info
      
      if ignored = infoxml['ignored']
        return ignored == '1'
      end
      
      return false
    end
    
    # Gets this person's location.
    def location
      infoxml = get_info
      return infoxml.at('location').inner_text
    end
    
    # Gets the mobile URL of this person's photos.
    def mobile_url
      infoxml = get_info
      return infoxml.at('mobileurl').inner_text
    end
    
    # Gets the total number of photos uploaded by this user.
    def photo_count
      infoxml = get_info
      return infoxml.at('photos/count').inner_text.to_i
    end
    
    # Gets the URL of this person's photo stream.
    def photo_url
      infoxml = get_info
      return infoxml.at('photosurl').inner_text
    end
    
    # Gets the number of times this person's photo stream has been viewed. This
    # method requires authentication with +read+ permission and only returns
    # information for the calling user. In all other cases, it returns +nil+.    
    def photo_views
      infoxml = get_info
      
      if views = infoxml.at('photos/views')
        return views.inner_text.to_i
      end
       
      return nil
    end
    
    # Gets a list of public photos for this person.
    # 
    # See http://flickr.com/services/api/flickr.people.getPublicPhotos.html for
    # details.
    def photos(args = {})
      return Net::Flickr.instance().photos.get_public_photos(@id, args)
    end
    
    # +true+ if this person is a Flickr Pro user, +false+ otherwise.
    def pro?
      infoxml = get_info
      return infoxml['ispro'] == '1'
    end
    
    # Gets the URL of this person's profile.
    def profile_url
      infoxml = get_info
      return infoxml.at('profileurl').inner_text
    end
    
    # Gets this person's real name (e.g., 'John Doe').
    def realname
      infoxml = get_info
      return infoxml.at('realname').inner_text
    end
    
    # +true+ if the calling user is a contact of this person, +false+ otherwise.
    # This method requires authentication with +read+ permission. In all other
    # cases, it returns +false+.
    def rev_contact?
      infoxml = get_info
      
      if rev_contact = infoxml['revcontact']
        return rev_contact == '1'
      end
      
      return false
    end
    
    # +true+ if this person considers the calling user family, +false+
    # otherwise. This method requires authentication with +read+ permission. In
    # all other cases, it returns +false+.
    def rev_family?
      infoxml = get_info
      
      if rev_family = infoxml['revfamily']
        return rev_family == '1'
      end
      
      return false
    end
    
    # +true+ if this person considers the calling user a friend, +false+
    # otherwise. This method requires authentication with +read+ permission. In
    # all other cases, it returns +false+.
    def rev_friend?
      infoxml = get_info
      
      if rev_friend = infoxml['revfriend']
        return rev_friend == '1'
      end
      
      return false
    end
    
    #--
    # Private Instance Methods
    #++
    
    private
    
    # Gets detailed information for this person.
    def get_info
      return @infoxml unless @infoxml.nil?
      
      response = Net::Flickr.instance().request('flickr.people.getInfo', 'user_id' => @id)
      
      return @infoxml = response.at('person')
    end

  end

end; end
