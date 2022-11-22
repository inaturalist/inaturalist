class Sound < ApplicationRecord
  belongs_to :user
  has_many :observation_sounds, :dependent => :destroy
  has_many :observations, :through => :observation_sounds

  serialize :native_response

  include Shared::LicenseModule
  acts_as_flaggable
  # include ActsAsUUIDable
  before_validation :set_uuid
  def set_uuid
    self.uuid ||= SecureRandom.uuid
    self.uuid = uuid.downcase
    true
  end

  attr_accessor :orphan
  
  def update(attributes)
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
  after_destroy :create_deleted_sound

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
    unless Rails.env.production?
      SoundcloudSound
      LocalSound
    end
    (self.subclasses || []).each do |klass|
      klass_key = klass.to_s.underscore.pluralize.to_sym
      if params[klass_key] && params[klass_key][fieldset_index.to_s]
        if klass == SoundcloudSound
          params[klass_key][fieldset_index.to_s].each do |sid|
            sound = klass.new_from_native_sound_id(sid, owner)
            sound.user = owner
            sound.native_realname = owner.soundcloud_identity.native_realname
            sounds << sound
          end
        else
          params[klass_key][fieldset_index.to_s].each do |file_or_id|
            sound = if file_or_id.is_a?( ActionDispatch::Http::UploadedFile )
              LocalSound.new( file: file_or_id )
            else
              Sound.find_by_id( file_or_id )
            end
            next unless sound
            sound.user = owner
            sound.native_realname = owner.name
            sounds << sound
          end
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
      license_code: index_license_code,
      attribution: attribution,
      native_sound_id: native_sound_id,
      secret_token: try(:secret_token),
      file_url: is_a?( LocalSound ) ? FakeView.uri_join( Site.default.url, file.url ) : nil,
      file_content_type: is_a?( LocalSound ) ? file.content_type : nil,
      play_local: is_a?( LocalSound ) && ( subtype.blank? || ( native_response && native_response["sharing"] == "private") ),
      subtype: subtype,
      flags: flags.map(&:as_indexed_json)
    }
  end

  def orphaned?
    return false if observation_sounds.loaded? ? observation_sounds.size > 0 : observation_sounds.exists?
    true
  end

  def create_deleted_sound
    DeletedSound.create(
      sound_id: id,
      user_id: user_id,
      orphan: orphan || false
    )
  end

  def self.destroy_orphans( ids )
    records = Sound.where( id: [ ids ].flatten ).includes( :observation_sounds )
    return if records.blank?
    records.each do |record|
      record.destroy if record.orphaned?
    end
  end

  def flagged_with(flag, options = {})
    flag_is_copyright = flag.flag == Flag::COPYRIGHT_INFRINGEMENT
    other_unresolved_copyright_flags_exist = flags.detect do |f|
      f.id != flag.id && f.flag == Flag::COPYRIGHT_INFRINGEMENT && !f.resolved?
    end
    # For copyright flags, we need to change the photo URLs when flagged, and
    # reset them when there are no more copyright flags
    if flag_is_copyright && !other_unresolved_copyright_flags_exist
      # TODO this is copypasta from photo.rb, but we should do something to
      # replace sounds with something equivalent to the copyright infringement
      # notice
      # if options[:action] == "created"
      #   styles = %w(original large medium small thumb square)
      #   updates = [styles.map{|s| "#{s}_url = ?"}.join(', ')]
      #   updates += styles.map do |s|
      #     FakeView.image_url("copyright-infringement-#{s}.png").to_s
      #   end
      #   Photo.where(id: id).update_all(updates)
      # elsif %w(resolved destroyed).include?(options[:action])
      #   Photo.repair_single_photo(self)
      # end
      observations.each(&:update_stats)
    end
    observations.each do |o|
      o.update_mappable
      o.elastic_index!
    end
  end

end
