class Sound < ActiveRecord::Base
  belongs_to :user
  has_many :observation_sounds, :dependent => :destroy
  has_many :observations, :through => :observation_sounds

  serialize :native_response
  ############### licensing
  attr_accessor :make_license_default
  attr_accessor :make_licenses_same
  cattr_accessor :descendent_classes

  MASS_ASSIGNABLE_ATTRIBUTES = [:make_license_default, :make_licenses_same]
  
  def update_attributes(attributes)
    MASS_ASSIGNABLE_ATTRIBUTES.each do |a|
      self.send("#{a}=", attributes.delete(a.to_s)) if attributes.has_key?(a.to_s)
      self.send("#{a}=", attributes.delete(a)) if attributes.has_key?(a)
    end
    super(attributes)
  end
  
  before_save :set_license, :trim_fields
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
    7 => {:code => "PD",                      :short => "PD",           :name => "Public domain", :url => "http://en.wikipedia.org/wiki/Public_domain"},
    8 => {:code => "GFDL",                    :short => "GFDL",         :name => "GNU Free Documentation License", :url => "http://www.gnu.org/copyleft/fdl.html"}
  }
  LICENSE_NUMBERS = LICENSE_INFO.keys
  LICENSE_INFO.each do |number, info|
    const_set info[:code].upcase.gsub(/\-/, '_'), number
  end

  validate :licensed_if_no_user
  
  def licensed_if_no_user
    if user.blank? && (license == COPYRIGHT || license.blank?)
      errors.add(
        :license, 
        "must be set if the sound wasn't added by a user.")
    end
  end
  
  def set_license
    return true unless license.blank?
    return true unless user
    self.license = Sound.license_number_for_code(user.preferred_sound_license)
    true
  end

  def trim_fields
    %w(native_realname native_username).each do |c|
      self.send("#{c}=", read_attribute(c).to_s[0..254]) if read_attribute(c)
    end
    true
  end
  
  # Return a string with attribution info about this sound
  def attribution
    name = if !native_realname.blank?
      native_realname
    elsif !native_username.blank?
      native_username
    elsif (o = observations.first)
      o.user.name || o.user.login
    else
      "anonymous"
    end
    if license == PD
      "#{name}, no known copyright restrictions (#{license_name})"
    elsif open_licensed?
      "(c) #{name}, some rights reserved (#{license_short})"
    else
      "(c) #{name}, all rights reserved"
    end
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

  def open_licensed?
    license.to_i > COPYRIGHT && license != PD
  end
  
  def update_default_license
    return true unless [true, "1", "true"].include?(@make_license_default)
    user.update_attribute(:preferred_sound_license, Sound.license_code_for_number(license))
    true
  end
  
  def update_all_licenses
    return true unless [true, "1", "true"].include?(@make_licenses_same)
    Sound.where(user_id: user_id).update_all(license: license)
    true
  end

  def editable_by?(user)
    return false if user.blank?
    user.id == user_id || observations.exists?(:user_id => user.id)
  end

  def self.license_number_for_code(code)
    return COPYRIGHT if code.blank?
    LICENSE_INFO.detect{|k,v| v[:code] == code}.try(:first)
  end
  
  def self.license_code_for_number(number)
    LICENSE_INFO[number].try(:[], :code)
  end

  def self.from_observation_params(params, fieldset_index, owner)
    sounds = []
    
    (self.descendent_classes || []).each do |klass|
      klass_key = klass.to_s.underscore.pluralize.to_sym
      if params[klass_key] && params[klass_key][fieldset_index.to_s]
        params[klass_key][fieldset_index.to_s].each do |sid|
          sound = klass.new_from_native_sound_id(sid, owner)
          sound.user = owner
          sound.native_realname = owner.soundcloud_identity.native_realname if klass == SoundcloudSound
          sounds << sound
        end
      end
    end
    sounds
  end

  def self.new_from_native_sound_id(sid, user)
    raise "This method needs to be implemented by all Sound subclasses"
  end

  def to_observation
    raise "This method needs to be implemented by all Sound subclasses"
  end

  def to_taxon
    return unless respond_to?(:to_taxa)
    sound_taxa = to_taxa(:lexicon => TaxonName::SCIENTIFIC_NAMES, :valid => true, :active => true)
    sound_taxa = to_taxa(:lexicon => TaxonName::SCIENTIFIC_NAMES) if sound_taxa.blank?
    sound_taxa = to_taxa if sound_taxa.blank?
    
    return if sound_taxa.blank?

    sound_taxa = sound_taxa.sort_by{|t| t.rank_level || Taxon::ROOT_LEVEL + 1}
    sound_taxa.detect(&:species_or_lower?) || sound_taxa.first
  end

  def as_indexed_json(options={})
    {
      id: id,
      license_code: license_code,
      attribution: attribution
    }
  end

end