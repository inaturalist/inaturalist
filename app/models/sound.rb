class Sound < ActiveRecord::Base
  belongs_to :user
  has_many :observation_sounds, :dependent => :destroy
  has_many :observations, :through => :observation_sounds

  serialize :native_response

  include Shared::LicenseModule
  
  def update_attributes(attributes)
    MASS_ASSIGNABLE_ATTRIBUTES.each do |a|
      self.send("#{a}=", attributes.delete(a.to_s)) if attributes.has_key?(a.to_s)
      self.send("#{a}=", attributes.delete(a)) if attributes.has_key?(a)
    end
    super(attributes)
  end
  
  before_save :set_license, :trim_fields
  after_save :update_default_license,
             :update_all_licenses,
             :index_observations

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
    self.license = Shared::LicenseModule.license_number_for_code(user.preferred_sound_license)
    true
  end

  def trim_fields
    %w(native_realname native_username).each do |c|
      self.send("#{c}=", read_attribute(c).to_s[0..254]) if read_attribute(c)
    end
    true
  end

  def update_default_license
    return true unless [true, "1", "true"].include?(make_license_default)
    user.update_attribute(:preferred_sound_license, Sound.license_code_for_number(license))
    true
  end
  
  def update_all_licenses
    return true unless [true, "1", "true"].include?(@make_licenses_same)
    Sound.where(user_id: user_id).update_all(license: license)
    true
  end

  def index_observations
    Observation.elastic_index!(scope: observations, delay: true)
  end

  def editable_by?(user)
    return false if user.blank?
    user.id == user_id || observations.exists?(:user_id => user.id)
  end

  def self.from_observation_params(params, fieldset_index, owner)
    sounds = []
    
    (self.subclasses || []).each do |klass|
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
      attribution: attribution,
      native_sound_id: native_sound_id,
      secret_token: secret_token
    }
  end

end
