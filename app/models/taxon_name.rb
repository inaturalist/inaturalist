#encoding: utf-8
class TaxonName < ActiveRecord::Base
  belongs_to :taxon, touch: true
  belongs_to :source
  belongs_to :creator, :class_name => 'User'
  belongs_to :updater, :class_name => 'User'
  has_many :taxon_scheme_taxa, :dependent => :destroy
  has_many :place_taxon_names, :dependent => :delete_all, :inverse_of => :taxon_name
  has_many :places, :through => :place_taxon_names
  validates_presence_of :taxon
  validates_length_of :name, :within => 1..256, :allow_blank => false
  validates_uniqueness_of :name, 
                          :scope => [:lexicon, :taxon_id], 
                          :message => "already exists for this taxon in this lexicon",
                          :case_sensitive => false
  validates_uniqueness_of :source_identifier,
                          :scope => [:taxon_id, :source_id],
                          :message => "already exists",
                          :allow_blank => true,
                          :unless => Proc.new {|taxon_name|
                            taxon_name.source && taxon_name.source.title =~ /Catalogue of Life/
                          }

  #TODO is the validates uniqueness correct?  Allows duplicate TaxonNames to be created with same 
  #source_url but different taxon_ids
  before_validation :strip_tags, :strip_name, :remove_rank_from_name, :normalize_lexicon
  before_validation do |tn|
    tn.name = tn.name.capitalize if tn.lexicon == LEXICONS[:SCIENTIFIC_NAMES]
  end
  before_save :set_is_valid
  after_create {|name| name.taxon.set_scientific_taxon_name}
  after_save :update_unique_names
  after_destroy {|name| name.taxon.delay(:priority => OPTIONAL_PRIORITY).update_unique_name if name.taxon}

  accepts_nested_attributes_for :place_taxon_names, :allow_destroy => true
  
  LEXICONS = {
    :SCIENTIFIC_NAMES    =>  'Scientific Names',
    :AFRIKAANS           =>  'Afrikaans',
    :BENGALI             =>  'Bengali',
    :CEBUANO             =>  'Cebuano',
    :CREOLE_FRENCH       =>  'creole (French)',
    :CREOLE_PORTUGUESE   =>  'creole (Portuguese)',
    :DAVAWENYO           =>  'Davawenyo',
    :DUTCH               =>  'Dutch',
    :ENGLISH             =>  'English',
    :FRENCH              =>  'French',
    :GELA                =>  'Gela',
    :GERMAN              =>  'German',
    :HAWAIIAN            =>  'Hawaiian',
    :HEBREW              =>  'Hebrew',
    :HILIGAYNON          =>  'Hiligaynon',
    :ICELANDIC           =>  'Icelandic',
    :ILOKANO             =>  'Ilokano',
    :ITALIAN             =>  'Italian',
    :JAPANESE            =>  'Japanese',
    :KOREAN              =>  'Korean',
    :MALTESE             =>  'Maltese',
    :MAORI               =>  'Maori',
    :MISIMA_PANEATI      =>  'Misima-paneati',
    :NORWEGIAN           =>  'Norwegian',
    :PANGASINAN          =>  'Pangasinan',
    :PORTUGUESE          =>  'Portuguese',
    :RUMANIAN            =>  'Rumanian',
    :RUSSIAN             =>  'Russian',
    :SPANISH             =>  'Spanish',
    :SWEDISH             =>  'Swedish',
    :TAGALOG             =>  'Tagalog',
    :TAHITIAN            =>  'Tahitian',
    :TOKELAUAN           =>  'Tokelauan',
    :TURKISH             =>  'Turkish',
    :WARAY_WARAY         =>  'Waray-Waray'
  }
  
  DEFAULT_LEXICONS = [
    LEXICONS[:SCIENTIFIC_NAMES],
    LEXICONS[:ENGLISH],
    LEXICONS[:SPANISH]
  ]
  
  LEXICONS.each do |k,v|
    class_eval <<-EOT
      def is_#{k.to_s.downcase}?
        lexicon == "#{v}"
      end
    EOT
    const_set k.to_s.upcase, v
  end
  alias :is_scientific? :is_scientific_names?
  
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
  
  def remove_rank_from_name
    return unless self.lexicon == LEXICONS[:SCIENTIFIC_NAMES]
    self.name = Taxon.remove_rank_from_name(self.name)
    true
  end
  
  def normalize_lexicon
    return true if lexicon.blank?
    self.lexicon = LEXICONS[lexicon.upcase.to_sym] if LEXICONS[lexicon.upcase.to_sym]
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

  def as_json(options = {})
    if options.blank?
      options[:only] = [:id, :name, :lexicon, :is_valid]
    end
    super(options)
  end

  def as_indexed_json(options={})
    json = {
      name: name.slice(0,1).capitalize + name.slice(1..-1),
      locale: locale_for_lexicon
    }
    if options[:autocomplete]
      json[:is_valid] = is_valid
      json[:name_autocomplete] = name
      if name.is_ja?
        json[:name_ja] = name
        json[:name_autocomplete_ja] = name
      end
      json[:exact] = name
    end
    json
  end

  def set_is_valid
    self.is_valid = true unless self.is_valid == false || lexicon == LEXICONS[:SCIENTIFIC_NAMES]
    self.is_valid = true if taxon.taxon_names.size <= 1
    true
  end
  
  def self.choose_common_name(taxon_names, options = {})
    return nil if taxon_names.blank?
    common_names = taxon_names.reject { |tn| tn.is_scientific_names? || !tn.is_valid? }
    return nil if common_names.blank?
    TaxonName.preload_associations(common_names, [:place_taxon_names])
    place_id = options[:place_id] unless options[:place_id].blank?
    place_id ||= (options[:place].is_a?(Place) ? options[:place].id : options[:place]) unless options[:place].blank?
    place_id ||= options[:user].place_id unless options[:user].blank?
    place_id ||= CONFIG.site.place_id if CONFIG.site && !CONFIG.site.place_id.blank?
    place = (options[:place].is_a?(Place) ? options[:place] : Place.find_by_id(place_id)) unless place_id.blank?
    common_names = common_names.sort_by{|tn| [tn.position, tn.id]}
    
    if place
      place_names = common_names.select{|tn| tn.place_taxon_names.detect{|ptn| ptn.place_id == place.id}}
      if place_names.blank?
        place_names = common_names.select{|tn| tn.place_taxon_names.detect{|ptn| 
          place.self_and_ancestor_ids.include?(ptn.place_id)
        }}
      end
      place_names = place_names.sort_by {|tn|
        ptn = tn.place_taxon_names.detect{|ptn| ptn.place_id == place.id}
        ptn ||= tn.place_taxon_names.detect{|ptn| place.self_and_ancestor_ids.include?(ptn.place_id)}
        [ptn.position, tn.position, tn.id]
      }
    else
      place_names = []
    end
    language_name = language_for_locale(options[:locale]) || 'english'
    locale_names = common_names.select {|n| n.localizable_lexicon == language_name}
    engnames = common_names.select {|n| n.is_english?}
    unknames = common_names.select {|n| n.lexicon == 'unspecified'}
    
    if place_names.length > 0
      place_names.first
    elsif locale_names.length > 0
      locale_names.first
    elsif engnames.length > 0
      engnames.first
    elsif unknames.length > 0
      unknames.first
    else
      common_names.first
    end
  end

  def serializable_hash(options = {})
    # don't use delete here, it will just remove the option for all 
    # subsequent records in an array
    options[:except] ||= []
    options[:except] += [:source_id, :source_identifier, :source_url, :name_provider, :creator_id, :updater_id]
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
    case localizable_lexicon
    when "scientific_names" then "sci"
    when "english" then "en"
    when "spanish" then "es"
    when "german" then "de"
    when "portuguese" then "pt"
    when "french" then "fr"
    when "chinese_traditional" then "zh"
    when "japanese" then "ja"
    when "maya" then "myn"
    when "dutch" then "nl"
    when "indonesian" then "id"
    when "hawaiian" then "haw"
    when "maori" then "mi"
    when "italian" then "it"
    else
      "und"
    end
  end

  def self.localizable_lexicon(lexicon)
    lexicon.to_s.gsub(' ', '_').gsub('-', '_').gsub(/[()]/,'').downcase
  end

  def self.language_for_locale(locale = nil)
    locale ||= I18n.locale
    case locale.to_s
    when /^es/    then 'spanish'
    when /^fr/    then 'french'
    when /zh.CN/i  then 'chinese_simplified'
    when /^zh/    then 'chinese_traditional'
    when /^pt/    then 'portuguese'
    when /^ja/    then 'japanese'
    else
      'english'
    end
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
    r.find(q).map do |ext_name|
      unless ext_name.valid?
        if existing_taxon = r.find_existing_taxon(ext_name.taxon)
          ext_name.taxon = existing_taxon
        end
      end
      ext_name.save ? ext_name : nil
    end.compact
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
end
