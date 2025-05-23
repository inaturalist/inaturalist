# frozen_string_literal: true

class Photo < ApplicationRecord
  acts_as_flaggable
  has_one :photo_metadata, autosave: true, dependent: :destroy
  belongs_to :user
  belongs_to :file_extension
  belongs_to :file_prefix
  has_many :observation_photos, dependent: :destroy
  has_many :taxon_photos, dependent: :destroy
  has_many :guide_photos, dependent: :destroy, inverse_of: :photo
  has_many :observations, through: :observation_photos
  has_many :taxa, through: :taxon_photos

  has_moderator_actions [
    ModeratorAction::HIDE,
    ModeratorAction::UNHIDE
  ]

  attr_accessor :api_response, :orphan,
    :remote_original_url,
    :remote_large_url,
    :remote_medium_url,
    :remote_small_url,
    :remote_square_url,
    :remote_thumb_url

  include Shared::LicenseModule
  include ActsAsUUIDable
  before_validation :set_uuid
  def set_uuid
    self.uuid ||= SecureRandom.uuid
    self.uuid = uuid.downcase
    true
  end

  before_save :set_license, :trim_fields
  after_save :update_default_license
  after_save :update_all_licenses
  after_commit :index_observations, :index_taxa, on: [:create, :update]
  after_destroy :create_deleted_photo

  SQUARE = 75
  THUMB = 100
  SMALL = 240
  MEDIUM = 500
  LARGE = 1024

  MIME_PATTERNS = [/jpe?g/i, /png/i, /gif/i, /heic/i, /heif/i, /octet-stream/].freeze

  class MissingPhotoError < StandardError; end

  def parse_extension
    return unless file.url( :original )

    ext = File.extname( URI.parse( file.url( :original ) ).path ).sub( ".", "" )
    ext.blank? ? nil : ext
  end

  def parse_url_prefix
    original = file.url( :original )
    return unless original

    if original !~ /http/
      original = UrlHelper.uri_join( UrlHelper.root_url, original ).to_s
    end
    if ( matches = original.match( %r{^(.*)/#{id}/original} ) )
      return matches[1]
    end

    nil
  end

  def original_url( options = {} )
    sized_url( :original, options )
  end

  def large_url( options = {} )
    sized_url( :large, options )
  end

  def medium_url( options = {} )
    sized_url( :medium, options )
  end

  def small_url( options = {} )
    sized_url( :small, options )
  end

  def square_url( options = {} )
    sized_url( :square, options )
  end

  def thumb_url( options = {} )
    sized_url( :thumb, options )
  end

  def processing?
    file_prefix.nil?
  end

  def sized_url( size = "original", options = {} )
    if flags.any? {| f | f.flag == Flag::COPYRIGHT_INFRINGEMENT && !f.resolved? } &&
        !options[:bypass_flags]
      return ApplicationController.helpers.image_url( "copyright-infringement-#{size}.png" )
    end
    if hidden?
      return ApplicationController.helpers.image_url( "media-hidden-#{size}.png" )
    end
    if instance_variable_get( "@remote_#{size}_url" )
      return instance_variable_get( "@remote_#{size}_url" )
    end
    if processing?
      return UrlHelper.uri_join( UrlHelper.root_url, LocalPhoto.new.file.url( size ) )
    end

    "#{file_prefix.prefix}/#{id}/#{size}.#{file_extension.extension}"
  end

  def to_s
    "<#{self.class} id: #{id}, user_id: #{user_id}>"
  end

  def to_plain_s
    "#{type.underscore.humanize} #{id} by #{attribution}"
  end

  def licensed_if_no_user
    return unless user.blank? && ( license == COPYRIGHT || license.blank? )

    errors.add(
      :license,
      "must be set if the photo wasn't added by a local user."
    )
  end

  def set_license
    return true unless license.nil?
    return true unless user

    if license.nil?
      self.license = Shared::LicenseModule.license_number_for_code( user.preferred_photo_license )
    end
    true
  end

  def trim_fields
    %w(native_realname native_username).each do | c |
      send( "#{c}=", read_attribute( c ).to_s[0..254] ) if read_attribute( c )
    end
    true
  end

  # Try to choose a single taxon for this photo.  Only works if class has
  # implemented to_taxa
  def to_taxon
    return unless respond_to?( :to_taxa )

    photo_taxa = to_taxa( lexicon: TaxonName::SCIENTIFIC_NAMES, valid: true, active: true )
    if photo_taxa.blank?
      photo_taxa = to_taxa( lexicon: TaxonName::SCIENTIFIC_NAMES, active: true )
    end
    if photo_taxa.blank?
      photo_taxa = if user && !user.locale.blank? && ( lexicon = TaxonName.language_for_locale( user.locale ) )
        to_taxa( lexicon: lexicon, active: true )
      else
        to_taxa( active: true )
      end
    end
    return if photo_taxa.blank?

    # If there are synonyms on the same branch, only keep the coarsest one
    # (e.g. if a genus and subgenus have the same name, throw out the
    # subgenus)
    photo_taxa = photo_taxa.group_by( &:name ).map do | _name, name_taxa |
      if name_taxa.size > 1
        sorted_taxa = name_taxa.sort_by {| t | t.rank_level.to_i }
        keepers = []
        while sorted_taxa.size.positive?
          t = sorted_taxa.shift
          unless sorted_taxa.detect {| st | t.ancestor_ids.include?( st.id ) }
            keepers << t
          end
        end
        keepers
      else
        name_taxa
      end
    end.flatten
    photo_taxa = photo_taxa.sort_by {| t | t.rank_level || ( Taxon::ROOT_LEVEL + 1 ) }
    candidate = photo_taxa.detect( &:species_or_lower? ) || photo_taxa.first
    # if there are synonyms, don't decide
    synonym = photo_taxa.detect {| t | t.name == candidate.name && t.id != candidate.id }
    synonym ||= photo_taxa.detect do | t |
      t_common_names = t.taxon_names.select do | tn |
        tn.is_valid? && tn.lexicon != TaxonName::SCIENTIFIC_NAMES
      end
      t_common_names.map! do | tn |
        tn.name.downcase
      end
      c_common_names = candidate.taxon_names.select do | tn |
        tn.is_valid? && tn.lexicon != TaxonName::SCIENTIFIC_NAMES
      end
      c_common_names.map! do | tn |
        tn.name.downcase
      end
      t.id != candidate.id && ( t_common_names & c_common_names ).size.positive?
    end
    if synonym
      nil
    else
      candidate
    end
  end

  # Sync photo object with its native source.  Implemented by descendents
  def sync
    nil
  end

  def update( attributes )
    MASS_ASSIGNABLE_ATTRIBUTES.each do | a |
      send( "#{a}=", attributes.delete( a.to_s ) ) if attributes.key?( a.to_s )
      send( "#{a}=", attributes.delete( a ) ) if attributes.key?( a )
    end
    super
  end

  def update_default_license
    return true unless [true, "1", "true"].include?( @make_license_default )

    user.update_attribute( :preferred_photo_license, Photo.license_code_for_number( license ) )
    true
  end

  def update_all_licenses
    return true unless [true, "1", "true"].include?( @make_licenses_same )

    Photo.where( user_id: user_id ).update_all( license: license )
    User.delay(
      queue: "photos",
      unique_hash: { "User::enqueue_photo_bucket_moving_jobs": user_id }
    ).enqueue_photo_bucket_moving_jobs( user_id )
    user.index_observations_later
    true
  end

  def index_observations
    Observation.elastic_index!( scope: observations )
  end

  def index_taxa
    return if taxon_ids.empty?

    Taxon.delay( unique_hash: { "Photo::index_taxa" => id } ).elastic_index!( ids: taxon_ids )
  end

  def editable_by?( user )
    return false if user.blank?

    user.id == user_id || observations.exists?( user_id: user.id )
  end

  def orphaned?
    return false if observation_photos.loaded? ? !observation_photos.empty? : observation_photos.exists?
    return false if taxon_photos.loaded? ? !taxon_photos.empty? : taxon_photos.exists?
    return false if guide_photos.loaded? ? !guide_photos.empty? : guide_photos.exists?

    true
  end

  def source_title
    t = if subtype == "PicasaPhoto" || is_a?( PicasaPhoto )
      "Google"
    end
    t ||= ( subtype || type ).gsub( /Photo$/, "" ).underscore.humanize.titleize
    t
  end

  def source_url
    # If it used to be an EOL photo and its native photo ID isn't an integer,
    # it's probably an EOL v2 data object identifier that EOL has lost track of
    if subtype == "EolPhoto" && !native_photo_id.blank? && native_photo_id.index( /[A-z]/ ).nil?
      return "https://eol.org/media/#{native_photo_id}"
    end
    if native_page_url =~ /#{source_title}/i
      return native_page_url
    end

    nil
  end

  def best_url( size = "medium" )
    size = size.to_s
    sizes = LocalPhoto::SIZES.map( &:to_s )
    size = "medium" unless sizes.include?( size )
    size_index = sizes.index( size )
    methods = sizes[size_index.to_i..].map {| s | "#{s}_url" } + ["original"]
    try_methods( *methods )
  end

  def serializable_hash( opts = nil )
    options = opts ? opts.clone : {}
    options[:except] ||= []
    options[:except] += [
      :metadata, :file_content_type, :file_file_name,
      :file_file_size, :file_processing, :file_updated_at, :mobile,
      :original_url
    ]
    options[:methods] ||= []
    options[:methods] += [
      :license_code,
      :license_name,
      :license_url,
      :attribution,
      :type,
      :square_url,
      :thumb_url,
      :small_url,
      :medium_url,
      :large_url
    ]
    super( options )
  end

  def flagged_with( flag, options = {} )
    flag_is_copyright = flag.flag == Flag::COPYRIGHT_INFRINGEMENT
    flags.reload
    other_unresolved_copyright_flags_exist = flags.detect do | f |
      f.id != flag.id && f.flag == Flag::COPYRIGHT_INFRINGEMENT && !f.resolved?
    end
    # flagged photos should move to the public bucket, so make sure they end up in the right place
    if is_a?( LocalPhoto ) && self["original_url"] !~ /copyright/
      change_photo_bucket_if_needed
    end
    if flag_is_copyright && !other_unresolved_copyright_flags_exist
      # For copyright flags reset the URLs if they still point to a copyright placeholder
      if %w(resolved destroyed).include?( options[:action] ) && self["original_url"] =~ /copyright/
        Photo.repair_single_photo( self )
      end
      observations.each( &:update_stats )
    end
    observations.each do | o |
      o.update_mappable
      Observation.set_quality_grade( o.id )
      o.elastic_index!
    end
    if flags.any? {| f | !f.resolved? } && taxon_photos.any?
      taxon_photos.each( &:destroy )
    end
    taxa.each( &:elastic_index! )
  end

  def moderated_with( _moderator_action, _options = {} )
    if is_a?( LocalPhoto )
      change_photo_bucket_if_needed
      reload
      set_acl
    end
    observations.each( &:update_stats )
    observations.each do | o |
      o.update_mappable
      Observation.set_quality_grade( o.id )
      o.elastic_index!
    end
    taxa.each( &:elastic_index! )
  end

  def original_dimensions
    {
      height: height,
      width: width
    }
  end

  def metadata
    photo_metadata&.metadata
  end

  def self.repair_photos_for_user( user, type )
    count = 0
    user.photos.where( type: type ).find_each do | photo |
      next if Photo.valid_remote_photo_url?( photo.original_url )
      next if Photo.valid_remote_photo_url?( photo.large_url )

      p, errors = photo.repair( no_save: true )
      unless errors.blank?
        Rails.logger.error "[ERROR] Failed to repair #{p}: #{errors.inspect}"
        next
      end
      Photo.turn_remote_photo_into_local_photo( p )
      unless p.valid?
        Rails.logger.error "[ERROR] Failed to save #{p}: #{p.errors.full_messages.to_sentence}"
        next
      end
      count += 1
    end
    Rails.logger.info "[INFO] Repaired #{count} #{type}s for #{user}"
  end

  def self.repair_single_photo( photo )
    if photo.subtype && ( klass = ( photo.subtype.constantize rescue nil ) ) && klass < Photo
      # we have a photo with a valid Photo subtype (cached remote photo)
      repair_photo = klass.new( photo.attributes.merge( type: photo.subtype ) )
      # repair as if it were the remote photo, but don't save anything
      repaired, errors = repair_photo.repair( no_save: true )
      unless errors.blank?
        return [photo, errors]
      end

      # if that succeded, update this photo with the repaired remote URL
      photo.file = URI( repaired.best_available_url )
      photo.save
      return [photo, {}]
    end
    return unless photo.respond_to?( :repair )

    repaired_photo, errors = photo.repair
    if errors.blank? && repaired_photo.user && !repaired_photo.is_a?( LocalPhoto )
      Photo.turn_remote_photo_into_local_photo( repaired_photo )
    end
    [repaired_photo, errors]
  end

  # used in the ObservationsController to create an un-saved
  # LocalPhoto from an unsaved remote photo and inherit
  # necessary attributes
  def self.local_photo_from_remote_photo( remote_photo )
    # inherit native_* and other attributes from remote photos
    return unless remote_photo.is_a?( Photo ) && remote_photo.type != "LocalPhoto"

    remote_photo_attrs = remote_photo.attributes.select do | k, _v |
      k =~ /^native/ ||
        ["user_id", "license", "mobile", "metadata"].include?( k )
    end
    photo_url = [:original, :large, :medium, :small].map do | s |
      remote_photo.instance_variable_get( "@remote_#{s}_url" )
    end.compact.first
    return unless photo_url

    if photo_url.size <= 512
      remote_photo_attrs["native_original_image_url"] = photo_url
    end
    remote_photo_attrs["subtype"] = remote_photo.class.name
    # stub this LocalPhoto's file with the remote photo URL
    remote_photo_attrs["file"] = URI( photo_url )
    LocalPhoto.new( remote_photo_attrs )
  end

  # to be used primarly for retroactive caching of remote photos
  def self.turn_remote_photo_into_local_photo( remote_photo )
    return unless remote_photo && remote_photo.class < Photo
    return unless ( fetch_url = remote_photo.best_available_url )

    remote_photo.type = "LocalPhoto"
    remote_photo.subtype = remote_photo.class.name
    if fetch_url.size <= 512
      remote_photo.native_original_image_url = fetch_url
    end
    remote_photo = remote_photo.becomes( LocalPhoto )
    remote_photo.file = URI( fetch_url )
    remote_photo.save
  end

  # to be used primarly for turn_remote_photo_into_local_photo
  def best_available_url
    [:original, :large, :medium, :small].each do | s |
      url = instance_variable_get( "@remote_#{s}_url" )
      if url && Photo.valid_remote_photo_url?( url )
        return url
      end
    end
    nil
  end

  def self.valid_remote_photo_url?( remote_photo_url )
    if ( head = fetch_head( remote_photo_url ) )
      # image must return 200 and have a valid image mime-type
      return head.code == "200" &&
          head.to_hash["content-type"].any? do | t |
            MIME_PATTERNS.any? {| mime_pattern | t =~ mime_pattern }
          end
    end
    false
  end

  # Like valid_remote_photo_url? this sends a HEAD request to see if an image is
  # still there, but it returns the URL if it is and will follow redirects up to
  # 5 times and return a valid URL if it finds one.
  def self.valid_remote_photo_url( remote_photo_url, options = {} )
    depth = options[:depth].to_i
    return false if depth > 5
    # Flickr's unavailable photo URL. When served from yimg they don't always
    # return a 404 status, so just checking the URL here.
    if remote_photo_url =~ /photo_unavailable\.png/
      return false
    end

    head = begin
      Timeout.timeout( 5 ) { fetch_head( remote_photo_url ) }
    rescue Timeout::Error
      false
    end
    return false unless head

    headers = head.to_hash
    if %w(301 302 303 307 308).include?( head.code ) && headers["location"]
      return valid_remote_photo_url( headers["location"][0], depth: depth + 1 )
    end
    if head.code == "200" && headers["content-type"].any? do | t |
      MIME_PATTERNS.any? {| mime_pattern | t =~ mime_pattern }
    end
      return remote_photo_url
    end

    false
  end

  # Retrieve info about a photo from its native source given its native id.
  # Should be implemented by descendents
  def self.get_api_response( _native_photo_id, _options = {} )
    nil
  end

  # Create a new Photo object from an API response.  Should be implemented by
  # descendents
  def self.new_from_api_response( _api_response, _options = {} )
    nil
  end

  # Destroy a photo if it no longer belongs to any observations or taxa
  def self.destroy_orphans( ids )
    photos = Photo.where( id: [ids].flatten )
    return if photos.blank?

    photos.each do | photo |
      photo.destroy if photo.orphaned?
    end
  end

  def self.default_json_options
    {
      methods: [
        :license_code, :attribution, :square_url,
        :thumb_url, :small_url, :medium_url, :large_url
      ],
      except: [
        :file_processing, :file_file_size,
        :file_content_type, :file_file_name, :mobile, :metadata, :user_id,
        :native_realname, :native_photo_id
      ]
    }
  end

  def as_indexed_json( options = {} )
    json = {
      id: id,
      license_code: index_license_code,
      attribution: attribution,
      url: ( is_a?( LocalPhoto ) && processing? ) ? file.url( :square ) : square_url,
      original_dimensions: original_dimensions,
      flags: flags.map( &:as_indexed_json )
    }
    json[:native_page_url] = native_page_url if options[:native_page_url]
    json[:native_photo_id] = native_photo_id if options[:native_photo_id]
    json[:type] = type if options[:type]
    json[:attribution_name] = attribution_name( allow_nil: true ) if options[:attribution_name]
    options[:sizes] ||= []
    options[:sizes].each do | size |
      json["#{size}_url"] = best_url( size )
    end
    json
  end

  def self.update_photo_native_columns_and_copy_metadata( min_id, max_id )
    start_time = Time.now
    counter = 0
    Photo.where( "id > ? AND id <= ?", min_id, max_id ).find_in_batches( batch_size: 100 ) do | batch |
      Photo.transaction do
        batch.each do | photo |
          if ( counter % 1000 ).zero?
            puts "#{counter}, ID: #{photo.id}, Time: #{( Time.now - start_time ).round( 2 )}"
          end
          counter += 1
          if photo.type == "LocalPhoto" && photo.subtype.blank? &&
              ( !photo.native_photo_id.nil? || !photo.native_page_url.nil? ||
                !photo.native_username.nil? || !photo.native_realname.nil? )
            photo.update_columns(
              native_photo_id: nil,
              native_page_url: nil,
              native_username: nil,
              native_realname: nil
            )
          end
          next if photo.metadata.blank?

          PhotoMetadata.where( photo_id: photo.id ).first_or_create
          PhotoMetadata.where( photo_id: photo.id ).update_all( metadata: photo.metadata )
        end
      end
    end
  end

  private

  def self.attributes_protected_by_default
    super - [inheritance_column]
  end

  def create_deleted_photo
    DeletedPhoto.create(
      photo_id: id,
      user_id: user_id,
      orphan: orphan || false
    )
  end
end
