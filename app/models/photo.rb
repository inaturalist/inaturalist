class Photo < ActiveRecord::Base
  belongs_to :user
  has_many :observation_photos, :dependent => :destroy
  has_many :taxon_photos, :dependent => :destroy
  has_many :observations, :through => :observation_photos
  has_many :taxa, :through => :taxon_photos
  
  attr_accessor :api_response
  
  # licensing extras
  attr_accessor :make_license_default
  attr_accessor :make_licenses_same
  MASS_ASSIGNABLE_ATTRIBUTES = [:make_license_default, :make_licenses_same]
  
  cattr_accessor :descendent_classes
  cattr_accessor :remote_descendent_classes
  
  before_save :set_license
  after_save :update_default_license,
             :update_all_licenses
  
  COPYRIGHT = 0
  NO_COPYRIGHT = 7
  
  LICENSE_INFO = {
    0 => {:code => "C",                       :short => "(c)",          :name => "Copyright", :url => "http://en.wikipedia.org/wiki/Copyright"},
    1 => {:code => Observation::CC_BY_NC_SA,  :short => "CC BY-NC-SA",  :name => "Attribution-NonCommercial-ShareAlike License", :url => "http://creativecommons.org/licenses/by-nc-sa/3.0/"},
    2 => {:code => Observation::CC_BY_NC,     :short => "CC BY-NC",     :name => "Attribution-NonCommercial License", :url => "http://creativecommons.org/licenses/by-nc/3.0/"},
    3 => {:code => Observation::CC_BY_NC_ND,  :short => "CC BY-NC-ND",  :name => "Attribution-NonCommercial-NoDerivs License", :url => "http://creativecommons.org/licenses/by-nc-nd/3.0/"},
    4 => {:code => Observation::CC_BY,        :short => "CC BY",        :name => "Attribution License", :url => "http://creativecommons.org/licenses/by/3.0/"},
    5 => {:code => Observation::CC_BY_SA,     :short => "CC BY-SA",     :name => "Attribution-ShareAlike License", :url => "http://creativecommons.org/licenses/by-sa/3.0/"},
    6 => {:code => Observation::CC_BY_ND,     :short => "CC BY-ND",     :name => "Attribution-NoDerivs License", :url => "http://creativecommons.org/licenses/by-nd/3.0/"},
    7 => {:code => "PD",                      :short => "PD",           :name => "Public domain, no known copyright restrictions", :url => "http://flickr.com/commons/usage/"}
  }
  
  def to_s
    "<#{self.class} id: #{id}, user_id: #{user_id}>"
  end
  
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
  
  def set_license
    return true unless license.blank?
    return true unless user
    self.license = Photo.license_number_for_code(user.preferred_photo_license)
    true
  end
  
  # Return a string with attribution info about this photo
  def attribution
    name = if !native_realname.blank?
      native_realname
    elsif !native_username.blank?
      native_username
    elsif (o = observations.first)
      o.user.name || o.user.login
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
  
  def license_code
    LICENSE_INFO[license.to_i].try(:[], :code)
  end
  
  def license_url
    LICENSE_INFO[license.to_i].try(:[], :url)
  end
  
  def copyrighted?
    license.to_i == COPYRIGHT
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
  
  def update_attributes(attributes)
    MASS_ASSIGNABLE_ATTRIBUTES.each do |a|
      self.send("#{a}=", attributes.delete(a.to_s)) if attributes.has_key?(a.to_s)
      self.send("#{a}=", attributes.delete(a)) if attributes.has_key?(a)
    end
    super(attributes)
  end
  
  def update_default_license
    return true unless [true, "1", "true"].include?(@make_license_default)
    user.update_attribute(:preferred_photo_license, Photo.license_code_for_number(license))
    true
  end
  
  def update_all_licenses
    return true unless [true, "1", "true"].include?(@make_licenses_same)
    Photo.update_all(["license = ?", license], ["user_id = ?", user_id])
    true
  end
  
  def editable_by?(user)
    return false if user.blank?
    user.id == user_id || observations.exists?(:user_id => user.id)
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
  
  def self.license_number_for_code(code)
    return COPYRIGHT if code.blank?
    LICENSE_INFO.detect{|k,v| v[:code] == code}.try(:first)
  end
  
  def self.license_code_for_number(number)
    LICENSE_INFO[number].try(:[], :code)
  end
  
end
