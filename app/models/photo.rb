class Photo < ActiveRecord::Base
  belongs_to :user
  has_many :observation_photos, :dependent => :destroy
  has_many :taxon_photos, :dependent => :destroy
  has_many :observations, :through => :observation_photos
  has_many :taxa, :through => :taxon_photos
  
  attr_accessor :api_response
  cattr_accessor :descendent_classes
  
  COPYRIGHT = 0
  NO_COPYRIGHT = 7
  
  LICENSE_INFO = {
    0 => {:short => "C", :name => "Copyright", :url => "http://en.wikipedia.org/wiki/Copyright"},
    1 => {:short => "CC BY-NC-SA", :name => "Attribution-NonCommercial-ShareAlike License", :url => "http://creativecommons.org/licenses/by-nc-sa/2.0/"},
    2 => {:short => "CC BY-NC", :name => "Attribution-NonCommercial License", :url => "http://creativecommons.org/licenses/by-nc/2.0/"},
    3 => {:short => "CC BY-NC-ND", :name => "Attribution-NonCommercial-NoDerivs License", :url => "http://creativecommons.org/licenses/by-nc-nd/2.0/"},
    4 => {:short => "CC BY", :name => "Attribution License", :url => "http://creativecommons.org/licenses/by/2.0/"},
    5 => {:short => "CC BY-SA", :name => "Attribution-ShareAlike License", :url => "http://creativecommons.org/licenses/by-sa/2.0/"},
    6 => {:short => "CC BY-ND", :name => "Attribution-NoDerivs License", :url => "http://creativecommons.org/licenses/by-nd/2.0/"},
    7 => {:short => "PD", :name => "Public domain, no known copyright restrictions", :url => "http://flickr.com/commons/usage/"}
  }
  
  def validate
    if user.blank? && self.license == 0
      errors.add(
        :license, 
        "must be a Creative Commons license if the photo wasn't added by " +
        "an iNaturalist user using their linked Flickr account.")
    end
    
    # Check to make sure the user owns the flickr photo
    if self.user && self.api_response
      if self.api_response.is_a?(Net::Flickr::Photo)
        fp_flickr_user_id = self.api_response.owner
      else
        fp_flickr_user_id = self.api_response.owner.nsid
      end
      
      unless fp_flickr_user_id == self.user.flickr_identity.flickr_user_id
        errors.add(:user, "must own the photo on Flickr.")
      end
    end
  end
  
  # Return a string with attribution info about this photo
  def attribution
    name = if !native_realname.blank?
      native_realname
    elsif !self.native_username.blank?
      native_username
    elsif !self.observations.empty?
      observations.first.user.login
    else
      "anonymous Flickr user"
    end
    "#{license_short} #{name}"
  end
  
  def license_short
    LICENSE_INFO[license.to_i].try(:[], :short)
  end
  
  def license_name
    LICENSE_INFO[license.to_i].try(:[], :name)
  end
  
  def creative_commons?
    license.to_i > COPYRIGHT && license.to_i < NO_COPYRIGHT
  end
  
  # Try to choose a single taxon for this photo.  Only works if class has 
  # implemented to_taxa
  def to_taxon
    photo_taxa_from_scinames = try(:to_taxa, :lexicon => TaxonName::SCIENTIFIC_NAMES)
    unless photo_taxa_from_scinames.blank?
      unless photo_taxa_from_scinames.detect{|t| t.rank_level.blank?}
        photo_taxa_from_scinames = photo_taxa_from_scinames.sort_by(&:rank_level)
      end
      return photo_taxa_from_scinames.detect(&:species_or_lower?) || photo_taxa_from_scinames.first
    end
    
    photo_taxa = try(:to_taxa)
    return nil if photo_taxa.blank?
    unless photo_taxa.detect{|t| t.rank_level.blank?}
      photo_taxa = photo_taxa.sort_by(&:rank_level)
    end
    photo_taxa.detect(&:species_or_lower?) || photo_taxa.first
  end
  
  # Sync photo object with its native source.  Implemented by descendents
  def sync
    nil
  end
  
  # Retrieve info about a photo from its native source given its native id.  
  # Should be implemented by descendents
  def self.get_api_response(native_photo_id, options = {})
    nil
  end
  
  # Create a new Photo object from an API response.  Should be implemented by 
  # descendents
  def self.new_from_api_response(api_response, options = {})
    nil
  end
  
  # Destroy a photo if it no longer belongs to any observations or taxa
  def self.destroy_orphans(ids)
    photos = Photo.all(:conditions => ["id IN (?)", [ids].flatten])
    return if photos.blank?
    photos.each do |photo|
      if !photo.observation_photos.exists? && !photo.taxon_photos.exists?
        photo.destroy
      end
    end
  end
  
end
