#encoding: utf-8
class TaxonName < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :source
  belongs_to :creator, :class_name => 'User'
  has_updater
  has_many :taxon_scheme_taxa, :dependent => :destroy
  has_many :place_taxon_names, :dependent => :delete_all, :inverse_of => :taxon_name
  has_many :places, :through => :place_taxon_names
  validates_presence_of :taxon
  validates_length_of :name, :within => 1..256, :allow_blank => false
  validates_uniqueness_of :name, scope: %i[parameterized_lexicon taxon_id], message: :already_exists, case_sensitive: false
  validates_format_of :lexicon, with: /\A[^\/,]+\z/, message: :should_not_contain_commas_or_slashes, allow_blank: true
  validate :species_common_name_cannot_match_taxon_name
  validate :valid_scientific_name_must_match_taxon_name
  validate :english_lexicon_if_exists, if: Proc.new { |tn| tn.lexicon && tn.lexicon_changed? }
  validate :parameterized_lexicon_present, if: Proc.new { |tn| tn.lexicon.present? }
  NAME_FORMAT = /\A([A-z]|\s|\-|×)+\z/
  validates :name, format: { with: NAME_FORMAT, message: :bad_format }, on: :create, if: Proc.new {|tn| tn.lexicon == SCIENTIFIC_NAMES}
  before_validation :strip_tags, :strip_name, :remove_rank_from_name, :normalize_lexicon
  # before_validation do |tn|
  #   tn.name = tn.name.capitalize if tn.lexicon == LEXICONS[:SCIENTIFIC_NAMES]
  # end
  before_validation :capitalize_scientific_name
  before_validation :parameterize_lexicon
  before_create {|name| name.position = name.taxon.taxon_names.size}
  before_save :set_is_valid
  after_create {|name| name.taxon.set_scientific_taxon_name}
  after_save :update_unique_names
  after_destroy {|name| name.taxon.delay(:priority => OPTIONAL_PRIORITY).update_unique_name if name.taxon}
  after_save :index_taxon
  after_destroy :index_taxon

  accepts_nested_attributes_for :place_taxon_names, :allow_destroy => true
  
  LEXICONS = {
    :SCIENTIFIC_NAMES    =>  'Scientific Names',
    :AFRIKAANS           =>  'Afrikaans',
    :ALBANIAN            =>  'Albanian',
    :BENGALI             =>  'Bengali',
    :CATALAN             =>  'Catalan',
    :CEBUANO             =>  'Cebuano',
    :CHINESE_TRADITIONAL =>  'Chinese (Traditional)',
    :CHINESE_SIMPLIFIED  =>  'Chinese (Simplified)',
    :CREOLE_FRENCH       =>  'creole (French)',
    :CREOLE_PORTUGUESE   =>  'creole (Portuguese)',
    :DAVAWENYO           =>  'Davawenyo',
    :DUTCH               =>  'Dutch',
    :ENGLISH             =>  'English',
    :ESTONIAN            =>  'Estonian',
    :FINNISH             =>  'Finnish',
    :FRENCH              =>  'French',
    :GELA                =>  'Gela',
    :GERMAN              =>  'German',
    :HAWAIIAN            =>  'Hawaiian',
    :HEBREW              =>  'Hebrew',
    :HILIGAYNON          =>  'Hiligaynon',
    :HUNGARIAN           =>  'Hungarian',
    :ICELANDIC           =>  'Icelandic',
    :ILOKANO             =>  'Ilokano',
    :ITALIAN             =>  'Italian',
    :JAPANESE            =>  'Japanese',
    :KOREAN              =>  'Korean',
    :LITHUANIAN          =>  'Lithuanian',
    :MALTESE             =>  'Maltese',
    :MAORI               =>  'Maori',
    :MISIMA_PANEATI      =>  'Misima-paneati',
    :NORWEGIAN           =>  'Norwegian',
    :PANGASINAN          =>  'Pangasinan',
    :POLISH              =>  'Polish',
    :PORTUGUESE          =>  'Portuguese',
    :RUMANIAN            =>  'Rumanian',
    :RUSSIAN             =>  'Russian',
    :SINHALA             =>  'Sinhala',
    :SLOVAK              =>  'Slovak',
    :SPANISH             =>  'Spanish',
    :SWEDISH             =>  'Swedish',
    :TAGALOG             =>  'Tagalog',
    :TAHITIAN            =>  'Tahitian',
    :THAI                =>  'Thai',
    :TOKELAUAN           =>  'Tokelauan',
    :TURKISH             =>  'Turkish',
    :UKRAINIAN           =>  'Ukrainian',
    :WARAY_WARAY         =>  'Waray-Waray'
  }
  
  LEXICONS.each do |k,v|
    class_eval <<-EOT
      def is_#{k.to_s.downcase}?
        lexicon == "#{v}"
      end
      alias :#{k.to_s.downcase}? :is_#{k.to_s.downcase}?
    EOT
    const_set k.to_s.upcase, v
  end

  LOCALES = {
    "afrikaans"             => "af",
    "albanian"              => "sq",
    "arabic"                => "ar",
    "basque"                => "eu",
    "breton"                => "br",
    "bulgarian"             => "bg",
    "catalan"               => "ca",
    "chinese_traditional"   => "zh",
    "chinese_simplified"    => "zh-CN",
    "czech"                 => "cs",
    "danish"                => "da",
    "dutch"                 => "nl",
    "english"               => "en",
    "esperanto"             => "eo",
    "estonian"              => "et",
    "filipino"              => "fil",
    "finnish"               => "fi",
    "french"                => "fr",
    "galician"              => "gl",
    "georgian"              => "ka",
    "german"                => "de",
    "greek"                 => "el",
    "hawaiian"              => "haw",
    "hebrew"                => "he",
    "hungarian"             => "hu",
    "indonesian"            => "id",
    "italian"               => "it",
    "japanese"              => "ja",
    "korean"                => "ko",
    "latvian"               => "lv",
    "lithuanian"            => "lt",
    "luxembourgish"         => "lb",
    "macedonian"            => "mk",
    "maori"                 => "mi",
    "maya"                  => "myn",
    "norwegian"             => "nb",
    "norwegian_bokmal"      => "nb",
    "ojibwe"                => "oj",
    "occitan"               => "oc",
    "polish"                => "pl",
    "portuguese"            => "pt",
    "romanian"              => "ro",
    "russian"               => "ru",
    "scientific_names"      => "sci",
    "sinhala"               => "si",
    "slovak"                => "sk",
    "spanish"               => "es",
    "swedish"               => "sv",
    "thai"                  => "th",
    "turkish"               => "tr",
    "ukrainian"             => "uk",
    "vietnamese"            => "vi"
  }
  LEXICONS_BY_LOCALE = LOCALES.invert.merge( "zh-TW" => "chinese_traditional" )

  DEFAULT_LEXICONS = [LEXICONS[:SCIENTIFIC_NAMES]] + I18N_SUPPORTED_LOCALES.map {|locale|
    LEXICONS_BY_LOCALE[locale] || LEXICONS_BY_LOCALE[locale.sub( /\-.+/, "" )] || I18n.t( "locales.#{locale}", locale: "en", default: nil )
  }.compact

  alias :is_scientific? :is_scientific_names?
  alias :scientific? :is_scientific_names?
  
  def to_s
    "<TaxonName #{self.id}: #{self.name} in #{self.lexicon}>"
  end
  
  def strip_name
    self.name.strip! if self.name
    true
  end
  
  def strip_tags
    self.name.gsub!(/<.*?>/, '')
    true
  end

  def capitalize_scientific_name
    return true unless lexicon == LEXICONS[:SCIENTIFIC_NAMES]
    self.name = Taxon.capitalize_scientific_name( name, taxon.try(:rank) )
    true
  end
  
  def remove_rank_from_name
    return unless self.lexicon == LEXICONS[:SCIENTIFIC_NAMES]
    self.name = Taxon.remove_rank_from_name(self.name)
    true
  end

  def self.normalize_lexicon(lexicon)
    return nil if lexicon.blank?
    return TaxonName::NORWEGIAN if lexicon == "norwegian_bokmal"
    # Correct a common misspelling
    return TaxonName::UKRAINIAN if lexicon.to_s.downcase.strip == "ukranian"
    ( LEXICONS[lexicon.underscore.upcase.to_sym] || lexicon.titleize ).strip
  end
  
  def normalize_lexicon
    return true if lexicon.blank?
    self.lexicon = TaxonName.normalize_lexicon(lexicon)
    true
  end
  
  def update_unique_names
    return true unless name_changed?
    non_unique_names = TaxonName.includes(:taxon).where(name: name).select("DISTINCT ON (taxon_id) *")
    non_unique_names.each do |taxon_name|
      taxon_name.taxon.update_unique_name if taxon_name.taxon
    end
    true
  end

  def as_json( options = {} )
    if options.blank?
      options[:only] = [:id, :name, :lexicon, :is_valid]
    end
    super( options )
  end

  def as_indexed_json(options={})
    json = {
      name: name.blank? ? nil : name,
      locale: locale_for_lexicon,
      position: position,
      place_taxon_names: place_taxon_names.map(&:as_indexed_json)
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
    self.is_valid = true unless self.is_valid == false || lexicon == LEXICONS[:SCIENTIFIC_NAMES]
    self.is_valid = true if taxon.taxon_names.size < (persisted? ? 2 : 1)
    true
  end
  
  def self.choose_common_name(taxon_names, options = {})
    return nil if taxon_names.blank?
    if options[:user] && !options[:user].prefers_common_names?
      return nil
    end
    common_names = taxon_names.reject { |tn| tn.is_scientific_names? || !tn.is_valid? }
    return nil if common_names.blank?
    place_id = options[:place_id] unless options[:place_id].blank?
    place_id ||= (options[:place].is_a?(Place) ? options[:place].id : options[:place]) unless options[:place].blank?
    place_id ||= options[:user].place_id unless options[:user].blank?
    
    if place_id.blank? && options[:site]
      place_id ||= options[:site].place_id unless options[:site].place_id.blank?
    end
    place = (options[:place].is_a?(Place) ? options[:place] : Place.find_by_id(place_id)) unless place_id.blank?
    common_names = common_names.sort_by{|tn| [tn.position, tn.id]}
    
    if place
      exact_place_names = common_names.select{|tn| tn.place_taxon_names.detect{|ptn| ptn.place_id == place.id}}
      place_names = []
      if exact_place_names.blank?
        place_names = common_names.select{|tn| tn.place_taxon_names.detect{|ptn| 
          place.self_and_ancestor_ids.include?(ptn.place_id)
        }}
      end
      name_sorter = Proc.new do |tn|
        ptn = tn.place_taxon_names.detect{|ptn| ptn.place_id == place.id}
        ptn ||= tn.place_taxon_names.detect{|ptn| place.self_and_ancestor_ids.include?(ptn.place_id)}
        [ptn.position, tn.position, tn.id]
      end
      place_names = place_names.sort_by( &name_sorter )
      exact_place_names = exact_place_names.sort_by( &name_sorter )
    else
      place_names = []
      exact_place_names = []
    end
    locale = options[:locale]
    locale = options[:user].try(:locale) if locale.blank?
    locale = options[:site].try(:locale) if locale.blank?
    locale = I18n.locale if locale.blank?
    language_name = language_for_locale( locale )
    locale_names = common_names.select {|n| n.localizable_lexicon == language_name }

    # We want Maori names to show up in New Zealand even for English speakers,
    # but we don't want North American English names to show in Mexcio
    locale_and_place_names = place_names.select {|n| n.localizable_lexicon == language_name }
    exact_locale_and_place_names = exact_place_names.select {|n| n.localizable_lexicon == language_name }
    
    if exact_locale_and_place_names.length > 0
      exact_locale_and_place_names.first
    elsif exact_place_names.length > 0
      exact_place_names.first
    elsif locale_and_place_names.length > 0
      locale_and_place_names.first
    elsif locale_names.length > 0
      locale_names.first
    end
  end

  def serializable_hash(opts = nil)
    # don't use delete here, it will just remove the option for all 
    # subsequent records in an array
    options = opts ? opts.clone : { }
    options[:except] ||= []
    options[:except] += [:source_id, :source_identifier, :source_url, :name_provider, :updater_id]
    if options[:only]
      options[:except] = options[:except] - options[:only]
    end
    options[:except].uniq!
    h = super(options)
    h
  end

  def localizable_lexicon
    TaxonName.localizable_lexicon(lexicon)
  end

  def locale_for_lexicon
    LOCALES[localizable_lexicon] || "und"
  end

  def index_taxon
    taxon.elastic_index! if taxon
  end

  def species_common_name_cannot_match_taxon_name
    if !is_scientific_names? && taxon && taxon.rank_level.to_i <= Taxon::SPECIES_LEVEL && taxon.name == name
      errors.add(:name, :cannot_match_the_scientific_name_of_a_species_for_this_lexicon)
    end
  end

  def valid_scientific_name_must_match_taxon_name
    if is_valid? && is_scientific_names? && taxon && name != taxon.name
      errors.add(:name, :must_match_the_taxon_if_valid)
    end
  end

  def self.localizable_lexicon(lexicon)
    lexicon.to_s.gsub(' ', '_').gsub('-', '_').gsub(/[()]/,'').downcase
  end

  def self.language_for_locale(locale = nil)
    locale ||= I18n.locale
    LOCALES.each do |language, language_locale|
      return "chinese_simplified" if locale.to_s =~ /zh.CN/i
      return language if locale.to_s =~ /^#{language_locale}/
    end
    nil
  end

  def self.choose_scientific_name(taxon_names)
    return nil if taxon_names.blank?
    taxon_names.select { |tn| tn.is_valid? && tn.is_scientific_names? }.first
  end
  
  def self.choose_default_name(taxon_names, options = {})
    return nil if taxon_names.blank?
    name = choose_common_name(taxon_names, options)
    name ||= choose_scientific_name(taxon_names)
    name ||= taxon_names.first
    name
  end
  
  def self.find_external(q, options = {})
    r = ratatosk(options)
    # fetch names and save them
    ext_names = r.find( q )
    existing = Taxon.where( name: ext_names.map(&:name) ).limit( 500 ).index_by(&:name)
    ext_names.map do |ext_name|
      unless ext_name.valid?
        if existing_taxon = r.find_existing_taxon(ext_name.taxon)
          ext_name.taxon = existing_taxon
        end
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
    ext_names.each do |ext_name|
      matching_tn_exists = ext_name.taxon.taxon_names.detect do |tn|
        tn.is_valid? && tn.name === ext_name.taxon.name
      end
      if !ext_name.valid? && ext_name.errors[:name] && matching_tn_exists
        ext_name.update_attributes( is_valid: false )
      end
    end
    ext_names
  end
  
  def self.find_single(name, options = {})
    lexicon = options.delete(:lexicon) # || TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
    name = name.split('_').join(' ')
    name = Taxon.remove_rank_from_name(name)
    conditions = {:name => name}
    conditions[:lexicon] = lexicon if lexicon
    begin
      taxon_names = TaxonName.where(conditions).limit(10).includes(:taxon)
    rescue ActiveRecord::StatementInvalid => e
      raise e unless e.message =~ /invalid byte sequence/
      conditions[:name] = name.encode('UTF-8')
      taxon_names = TaxonName.where(conditions).limit(10).includes(:taxon)
    end
    unless options[:iconic_taxa].blank?
      taxon_names.reject {|tn| options[:iconic_taxa].include?(tn.taxon.iconic_taxon_id)}
    end
    taxon_names.detect{|tn| tn.is_valid?} || taxon_names.first
  end
  
  def self.strip_author(name)
    name = name.gsub(' hor ', ' ')
    name = name.gsub(' de ', ' ')
    name = name.gsub(/\(.*?\).*/, '')
    name = name.gsub(/\[.*?\]/, '')
    name = name.gsub(/[\w\.,]+\s+\d+.*/, '')
    name = name.gsub(/\w[\.,]+.*/, '')
    name = name.gsub(/\s+[A-Z].*/, '')
    name.strip
  end
  
  def self.find_lexicons_by_translation(translation)
    lex_by_loc = I18n.available_locales.each_with_object({}) do |loc, hash|
      hash[loc] = I18n.with_locale(loc) { I18n.t(:lexicons) }
    end
    match_loc, match_lexes = lex_by_loc.reject{|l| l.match("en") }
                                 .transform_values { |loc| loc.transform_values { |lex| lex.downcase.strip } }
                                 .find { |_loc, lexes| lexes.values.include?(translation.downcase.strip) }
    
    { locale: match_loc, lexicons: match_lexes }
  end

  private

  def english_lexicon_if_exists
    en_lexicons = I18n.with_locale(:en) { I18n.t(:lexicons) }.values
    translated_lexicons = I18n.available_locales.map { |loc| I18n.with_locale(loc) { I18n.t(:lexicons) } }
    non_en_lexicons = (translated_lexicons.collect(&:values).flatten.uniq - en_lexicons).map!{ |l| l.downcase.strip }
    match = TaxonName.find_lexicons_by_translation(lexicon)

    if non_en_lexicons.include?(lexicon.downcase.strip)
      errors.add(:lexicon, :should_match_english_translation, {
        suggested:  I18n.with_locale(:en) { I18n.t("lexicons.#{match[:lexicons].key(lexicon.downcase.strip)}")},
        suggested_locale: I18n.t("locales.#{match[:locale]}")
      })
    end
  end

  def parameterize_lexicon
    return unless lexicon.present?

    self.parameterized_lexicon = lexicon.parameterize
  end

  def parameterized_lexicon_present
    errors.add(:lexicon, :should_be_in_english) if lexicon.parameterize.empty?
  end
end
