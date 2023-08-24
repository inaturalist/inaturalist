# frozen_string_literal: true

class TaxonName < ApplicationRecord
  audited except: [
    :creator_id,
    :parameterized_lexicon,
    :taxon_id,
    :updater_id
  ], associated_with: :taxon
  belongs_to :taxon
  belongs_to :source
  belongs_to :creator, class_name: "User"
  has_updater
  has_many :taxon_scheme_taxa, dependent: :destroy
  has_many :place_taxon_names, dependent: :delete_all, inverse_of: :taxon_name
  has_many :places, through: :place_taxon_names
  validates_presence_of :taxon
  validates_length_of :name, within: 1..256, allow_blank: false
  validates_uniqueness_of :name, scope: %i[parameterized_lexicon taxon_id],
    message: :already_exists,
    case_sensitive: false
  validates :lexicon, presence: true, if: proc {| tn | tn.lexicon_changed? || tn.new_record? }
  validate :no_forbidden_lexicons
  validates_format_of :lexicon, with: %r{\A[^/,]+\z},
    message: :should_not_contain_commas_or_slashes,
    if: proc {| tn | tn.lexicon_changed? }
  validate :species_common_name_cannot_match_taxon_name
  validate :valid_scientific_name_must_match_taxon_name
  validate :english_lexicon_if_exists, if: proc {| tn | tn.lexicon && tn.lexicon_changed? }
  validate :parameterized_lexicon_present, if: proc {| tn | tn.lexicon.present? }
  validate :user_submitted_names_need_notes
  SCIENTIFIC_NAME_FORMAT = /\A([A-z]|\s|-|×)+\z/
  validates :name,
    format: { with: SCIENTIFIC_NAME_FORMAT, message: :bad_format },
    if: proc {| tn |
      tn.lexicon == SCIENTIFIC_NAMES && ( tn.name_changed? || tn.new_record? )
    }
  before_validation :strip_tags, :strip_name, :remove_rank_from_name, :normalize_lexicon
  before_validation :capitalize_scientific_name
  before_validation :parameterize_lexicon
  before_create {| name | name.position = name.taxon.taxon_names.size }
  before_save :set_is_valid
  after_create {| name | name.taxon.set_scientific_taxon_name }
  after_save :index_taxon
  after_destroy :index_taxon

  accepts_nested_attributes_for :place_taxon_names, allow_destroy: true

  LEXICONS = {
    SCIENTIFIC_NAMES: "Scientific Names",
    AFRIKAANS: "Afrikaans",
    ALBANIAN: "Albanian",
    ARABIC: "Arabic",
    BELARUSIAN: "Belarusian",
    BENGALI: "Bengali",
    CATALAN: "Catalan",
    CEBUANO: "Cebuano",
    CHINESE_SIMPLIFIED: "Chinese (Simplified)",
    CHINESE_TRADITIONAL: "Chinese (Traditional)",
    CREOLE_FRENCH: "creole (French)",
    CREOLE_PORTUGUESE: "creole (Portuguese)",
    CZECH: "Czech",
    DANISH: "Danish",
    DAVAWENYO: "Davawenyo",
    DUTCH: "Dutch",
    ENGLISH: "English",
    ESPERANTO: "Esperanto",
    ESTONIAN: "Estonian",
    FINNISH: "Finnish",
    FRENCH: "French",
    GELA: "Gela",
    GEORGIAN: "Georgian",
    GERMAN: "German",
    GREEK: "Greek",
    HAWAIIAN: "Hawaiian",
    HEBREW: "Hebrew",
    HILIGAYNON: "Hiligaynon",
    HUNGARIAN: "Hungarian",
    ICELANDIC: "Icelandic",
    ILOKANO: "Ilokano",
    ITALIAN: "Italian",
    JAPANESE: "Japanese",
    KANNADA: "Kannada",
    KAZAKH: "Kazakh",
    KOREAN: "Korean",
    LATVIAN: "Latvian",
    LITHUANIAN: "Lithuanian",
    LUXEMBOURGISH: "Luxembourgish",
    MALTESE: "Maltese",
    MAORI: "Maori",
    MARATHI: "Marathi",
    MISIMA_PANEATI: "Misima-paneati",
    NORWEGIAN: "Norwegian",
    OCCITAN: "Occitan",
    PANGASINAN: "Pangasinan",
    PERSIAN: "Persian",
    POLISH: "Polish",
    PORTUGUESE: "Portuguese",
    ROMANIAN: "Romanian",
    RUSSIAN: "Russian",
    SANTALI: "Santali",
    SERBIAN: "Serbian",
    TSWANA: "Tswana",
    SINHALA: "Sinhala",
    SLOVAK: "Slovak",
    SLOVENIAN: "Slovenian",
    SPANISH: "Spanish",
    SWAHILI: "Swahili",
    SWEDISH: "Swedish",
    TAGALOG: "Tagalog",
    TAHITIAN: "Tahitian",
    THAI: "Thai",
    TOKELAUAN: "Tokelauan",
    TURKISH: "Turkish",
    UKRAINIAN: "Ukrainian",
    WARAY_WARAY: "Waray-Waray"
  }.freeze

  LEXICONS.each do | k, v |
    define_method "is_#{k.to_s.downcase}?".to_sym do
      lexicon == v
    end
    alias_method :"#{k.to_s.downcase}?", :"is_#{k.to_s.downcase}?"
    const_set k.to_s.upcase, v
  end

  FORBIDDEN_LEXICONS = %w(unknown lexicon other).freeze

  LOCALES = {
    "afrikaans" => "af",
    "albanian" => "sq",
    "arabic" => "ar",
    "basque" => "eu",
    "belarusian" => "be",
    "breton" => "br",
    "bulgarian" => "bg",
    "catalan" => "ca",
    "chinese_traditional" => "zh",
    "chinese_simplified" => "zh-CN",
    "croatian" => "hr",
    "czech" => "cs",
    "danish" => "da",
    "dutch" => "nl",
    "english" => "en",
    "esperanto" => "eo",
    "estonian" => "et",
    "filipino" => "fil",
    "finnish" => "fi",
    "french" => "fr",
    "galician" => "gl",
    "georgian" => "ka",
    "german" => "de",
    "greek" => "el",
    "hawaiian" => "haw",
    "hebrew" => "he",
    "hungarian" => "hu",
    "indonesian" => "id",
    "italian" => "it",
    "japanese" => "ja",
    "kannada" => "kn",
    "kazakh" => "kk",
    "korean" => "ko",
    "latvian" => "lv",
    "lithuanian" => "lt",
    "luxembourgish" => "lb",
    "macedonian" => "mk",
    "maori" => "mi",
    "marathi" => "mr",
    "maya" => "myn",
    "norwegian" => "nb",
    "norwegian_bokmal" => "nb",
    "ojibwe" => "oj",
    "occitan" => "oc",
    "persian" => "fa",
    "polish" => "pl",
    "portuguese" => "pt",
    "romanian" => "ro",
    "russian" => "ru",
    "santali" => "sat",
    "scientific_names" => "sci",
    "serbian" => "sr",
    "sinhala" => "si",
    "slovak" => "sk",
    "slovenian" => "sl",
    "spanish" => "es",
    "swahili" => "sw",
    "swedish" => "sv",
    "thai" => "th",
    "turkish" => "tr",
    "ukrainian" => "uk",
    "vietnamese" => "vi"
  }.freeze
  LEXICONS_BY_LOCALE = LOCALES.invert.merge( "zh-TW" => "chinese_traditional" )

  DEFAULT_LEXICONS = [LEXICONS[:SCIENTIFIC_NAMES]] + I18N_SUPPORTED_LOCALES.map do | locale |
    LEXICONS_BY_LOCALE[locale] || LEXICONS_BY_LOCALE[locale.sub( /-.+/,
      "" )] || I18n.t( "locales.#{locale}", locale: "en", default: nil )
  end.compact

  alias is_scientific? is_scientific_names?
  alias scientific? is_scientific_names?

  attr_accessor :skip_indexing
  attr_accessor :user_submission

  def to_s
    "<TaxonName #{id}: #{name} in #{lexicon}>"
  end

  def strip_name
    name&.strip!
    true
  end

  def strip_tags
    name.gsub!( /<.*?>/, "" ) unless name.blank?
    true
  end

  def capitalize_scientific_name
    return true unless lexicon == LEXICONS[:SCIENTIFIC_NAMES]

    self.name = Taxon.capitalize_scientific_name( name, taxon.try( :rank ) )
    true
  end

  def remove_rank_from_name
    return unless lexicon == LEXICONS[:SCIENTIFIC_NAMES]

    self.name = Taxon.remove_rank_from_name( name )
    true
  end

  def self.normalize_lexicon( lexicon )
    return nil if lexicon.blank?
    return TaxonName::NORWEGIAN if lexicon == "norwegian_bokmal"
    return TaxonName::PERSIAN if lexicon.to_s.downcase.strip == "farsi"
    return TaxonName::ROMANIAN if lexicon.to_s.downcase.strip == "rumanian"
    return TaxonName::SWAHILI if lexicon.to_s.downcase.strip == "kiswahili"
    return TaxonName::SWAHILI if lexicon.to_s =~ /^swahili/
    # Correct a common misspelling
    return TaxonName::UKRAINIAN if lexicon.to_s.downcase.strip == "ukranian"

    ( LEXICONS[lexicon.underscore.upcase.to_sym] || lexicon.titleize ).strip
  end

  def normalize_lexicon
    return true if lexicon.blank?

    self.lexicon = TaxonName.normalize_lexicon( lexicon )
    true
  end

  def as_json( options = {} )
    if options.blank?
      options[:only] = [:id, :name, :lexicon, :is_valid]
    end
    super( options )
  end

  def as_indexed_json( options = {} )
    json = {
      name: name.blank? ? nil : name,
      locale: locale_for_lexicon,
      lexicon: parameterized_lexicon,
      position: position,
      place_taxon_names: place_taxon_names.map( &:as_indexed_json )
    }
    if options[:autocomplete]
      json[:is_valid] = is_valid
      json[:name_autocomplete] = name
      if name.is_ja?
        json[:name_ja] = name
        json[:name_autocomplete_ja] = name
      end
      json[:exact] = name
      json[:exact_ci] = name
    end
    json
  end

  def set_is_valid
    self.is_valid = true unless is_valid == false || lexicon == LEXICONS[:SCIENTIFIC_NAMES]
    self.is_valid = true if taxon.taxon_names.size < ( persisted? ? 2 : 1 )
    true
  end

  def self.choose_common_name( taxon_names, options = {} )
    return nil if taxon_names.blank?
    if options[:user] && !options[:user].prefers_common_names?
      return nil
    end

    common_names = taxon_names.reject {| tn | tn.is_scientific_names? || !tn.is_valid? }
    return nil if common_names.blank?

    place_id = options[:place_id] unless options[:place_id].blank?
    place_id ||= ( options[:place].is_a?( Place ) ? options[:place].id : options[:place] ) unless options[:place].blank?
    place_id ||= options[:user].place_id unless options[:user].blank?

    if place_id.blank? && options[:site] && !options[:site].place_id.blank?
      place_id ||= options[:site].place_id
    end
    place = ( options[:place].is_a?( Place ) ? options[:place] : Place.find_by_id( place_id ) ) unless place_id.blank?
    common_names = common_names.sort_by {| tn | [tn.position, tn.id] }

    if place
      exact_place_names = common_names.select {| tn | tn.place_taxon_names.detect {| ptn | ptn.place_id == place.id } }
      place_names = []
      if exact_place_names.blank?
        place_names = common_names.select do | tn |
          tn.place_taxon_names.detect do | ptn |
            place.self_and_ancestor_ids.include?( ptn.place_id )
          end
        end
      end
      name_sorter = proc do | tn |
        ptn = tn.place_taxon_names.detect {| ptn1 | ptn1.place_id == place.id }
        ptn ||= tn.place_taxon_names.detect {| ptn2 | place.self_and_ancestor_ids.include?( ptn2.place_id ) }
        [ptn.position, tn.position, tn.id]
      end
      place_names = place_names.sort_by( &name_sorter )
      exact_place_names = exact_place_names.sort_by( &name_sorter )
    else
      place_names = []
      exact_place_names = []
    end
    locale = options[:locale]
    locale = options[:user].try( :locale ) if locale.blank?
    locale = options[:site].try( :locale ) if locale.blank?
    locale = I18n.locale if locale.blank?
    language_name = language_for_locale( locale )
    locale_names = common_names.select {| n | n.localizable_lexicon == language_name }

    # We want Maori names to show up in New Zealand even for English speakers,
    # but we don't want North American English names to show in Mexcio
    locale_and_place_names = place_names.select {| n | n.localizable_lexicon == language_name }
    exact_locale_and_place_names = exact_place_names.select {| n | n.localizable_lexicon == language_name }

    if exact_locale_and_place_names.length.positive?
      exact_locale_and_place_names.first
    elsif exact_place_names.length.positive?
      exact_place_names.first
    elsif locale_and_place_names.length.positive?
      locale_and_place_names.first
    elsif locale_names.length.positive?
      locale_names.first
    end
  end

  def serializable_hash( opts = nil )
    # don't use delete here, it will just remove the option for all
    # subsequent records in an array
    options = opts ? opts.clone : {}
    options[:except] ||= []
    options[:except] += [:source_id, :source_identifier, :source_url, :name_provider, :updater_id]
    if options[:only]
      options[:except] = options[:except] - options[:only]
    end
    options[:except].uniq!
    super( options )
  end

  def localizable_lexicon
    TaxonName.localizable_lexicon( lexicon )
  end

  def locale_for_lexicon
    # Note that `und` is an official ISO 639 code for "Undetermined". See https://en.wikipedia.org/wiki/ISO_639:u
    LOCALES[localizable_lexicon] || "und"
  end

  def index_taxon
    taxon.elastic_index! if taxon && !skip_indexing
  end

  def species_common_name_cannot_match_taxon_name
    return unless !is_scientific_names? && taxon && taxon.rank_level.to_i <= Taxon::SPECIES_LEVEL && taxon.name == name

    errors.add( :name, :cannot_match_the_scientific_name_of_a_species_for_this_lexicon )
  end

  def valid_scientific_name_must_match_taxon_name
    return unless is_valid? && is_scientific_names? && taxon && name != taxon.name

    errors.add( :name, :must_match_the_taxon_if_valid )
  end

  def no_forbidden_lexicons
    return unless new_record? || lexicon_changed?
    return unless lexicon =~ /(#{FORBIDDEN_LEXICONS.join( "|" )})/i

    errors.add(
      :lexicon,
      I18n.t( "lexicon_cannot_contain_words", words: FORBIDDEN_LEXICONS.join( ", " ) )
    )
  end

  def self.localizable_lexicon( lexicon )
    lexicon.to_s.gsub( " ", "_" ).gsub( "-", "_" ).gsub( /[()]/, "" ).downcase
  end

  def self.language_for_locale( locale = nil )
    locale ||= I18n.locale
    LOCALES.each do | language, language_locale |
      return "chinese_simplified" if locale.to_s =~ /zh.CN/i
      return language if locale.to_s =~ /^#{language_locale}/
    end
    nil
  end

  def self.choose_scientific_name( taxon_names )
    return nil if taxon_names.blank?

    taxon_names.select {| tn | tn.is_valid? && tn.is_scientific_names? }.first
  end

  def self.choose_default_name( taxon_names, options = {} )
    return nil if taxon_names.blank?

    name = choose_common_name( taxon_names, options )
    name ||= choose_scientific_name( taxon_names )
    name ||= taxon_names.first
    name
  end

  def self.find_external( query, options = {} )
    r = ratatosk( options )
    # fetch names and save them
    ext_names = r.find( query )
    existing = Taxon.where( name: ext_names.map( &:name ) ).limit( 500 ).index_by( &:name )
    ext_names.map do | ext_name |
      if !ext_name.valid? && ( existing_taxon = r.find_existing_taxon( ext_name.taxon ) )
        ext_name.taxon = existing_taxon
      end
      if existing[ext_name.name]
        # don't bother creating new synonymous taxa
        nil
      elsif ext_name.save
        ext_name
      else
        Rails.logger.debug "[DEBUG] Failed to save ext_name: #{ext_name.errors.full_messages.to_sentence}"
        nil
      end
    end.compact
    ext_names.each do | ext_name |
      matching_tn_exists = ext_name.taxon.taxon_names.detect do | tn |
        tn.is_valid? && tn.name == ext_name.taxon.name
      end
      if !ext_name.valid? && ext_name.errors[:name] && matching_tn_exists
        ext_name.update( is_valid: false )
      end
    end
    ext_names
  end

  def self.find_single( name, options = {} )
    lexicon = options.delete( :lexicon ) # || TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
    name = name.split( "_" ).join( " " )
    name = Taxon.remove_rank_from_name( name )
    conditions = { name: name }
    conditions[:lexicon] = lexicon if lexicon
    begin
      taxon_names = TaxonName.where( conditions ).limit( 10 ).includes( :taxon )
    rescue ActiveRecord::StatementInvalid => e
      raise e unless e.message =~ /invalid byte sequence/

      conditions[:name] = name.encode( "UTF-8" )
      taxon_names = TaxonName.where( conditions ).limit( 10 ).includes( :taxon )
    end
    unless options[:iconic_taxa].blank?
      taxon_names.reject {| tn | options[:iconic_taxa].include?( tn.taxon.iconic_taxon_id ) }
    end
    taxon_names.detect( &:is_valid? ) || taxon_names.first
  end

  def self.strip_author( name )
    name = name.gsub( " hor ", " " )
    name = name.gsub( " de ", " " )
    name = name.gsub( /\(.*?\).*/, "" )
    name = name.gsub( /\[.*?\]/, "" )
    name = name.gsub( /[\w.,]+\s+\d+.*/, "" )
    name = name.gsub( /\w[.,]+.*/, "" )
    name = name.gsub( /\s+[A-Z].*/, "" )
    name.strip
  end

  def self.find_lexicons_by_translation( translation )
    lex_by_loc = I18n.available_locales.each_with_object( {} ) do | loc, hash |
      hash[loc] = I18n.with_locale( loc ) { I18n.t( :lexicons ) }
    end
    match_loc, match_lexes = lex_by_loc.reject {| l | l.match( "en" ) }.
      transform_values {| loc | loc.transform_values {| lex | lex.downcase.strip } }.
      find {| _loc, lexes | lexes.values.include?( translation.downcase.strip ) }

    { locale: match_loc, lexicons: match_lexes }
  end

  def self.all_lexicons
    Rails.cache.fetch( "TaxonName::all_lexicons", expires_in: 1.hour ) do
      Hash[TaxonName.where( "lexicon IS NOT NULL" ).distinct.pluck( :lexicon ).map do |l|
        [l.parameterize, l]
      end.sort].filter{ |k,v| !k.blank? }
    end
  end

  private

  def english_lexicon_if_exists
    en_lexicons = I18n.t( :lexicons, locale: :en ).
      values.
      map {| l | l.downcase.strip }.
      uniq
    translated_lexicons = I18n.available_locales.
      map {| loc | I18n.t( :lexicons, locale: loc ) }.
      collect( &:values ).
      flatten.
      map {| l | l.downcase.strip }.
      uniq
    non_en_lexicons = translated_lexicons - en_lexicons
    match = TaxonName.find_lexicons_by_translation( lexicon )
    return unless non_en_lexicons.include?( lexicon.downcase.strip )

    errors.add( :lexicon, :should_match_english_translation,
      suggested: I18n.with_locale( :en ) { I18n.t( "lexicons.#{match[:lexicons].key( lexicon.downcase.strip )}" ) },
      suggested_locale: I18n.t( "locales.#{match[:locale]}" ) )
  end

  def parameterize_lexicon
    return unless lexicon.present?

    self.parameterized_lexicon = lexicon.parameterize
  end

  def parameterized_lexicon_present
    errors.add( :lexicon, :should_be_in_english ) if lexicon.parameterize.empty?
  end

  def user_submitted_names_need_notes( options = { } )
    return unless user_submission
    return unless options[:ignore_field_checks] || name_changed? ||
      is_valid_changed? || lexicon_changed? ||
      place_taxon_names.any?{ |ptn| ptn.changes.without( :position ).any? }
    if audit_comment.blank? || audit_comment.length < 10
      errors.add( :audit_comment, :needs_to_be_at_least_10_characters )
    end
  end

  # audited was setting the audit_comment to nil before a `before_destroy` callback was being
  # called. So even if the destroy was aborted and the audit transaction was rolled back, the
  # audited_comment was nil after the abort, and that prevented the audit_comment from being
  # displayed in the redisplayed taxon name edit form. This ensures the destroy validations
  # happen before audited has a change to delete the audit_comment
  def audit_destroy
    user_submitted_names_need_notes( ignore_field_checks: true )
    throw( :abort ) unless errors.details[:audit_comment].blank?
    super
  end

end
