#encoding: utf-8
class TaxonName < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :source
  belongs_to :creator, :class_name => 'User'
  belongs_to :updater, :class_name => 'User'
  has_many :taxon_scheme_taxa, :dependent => :destroy
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
  after_create {|name| name.taxon.set_scientific_taxon_name}
  after_save :update_unique_names
  after_destroy {|name| name.taxon.delay(:priority => OPTIONAL_PRIORITY).update_unique_name if name.taxon}
  
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
    non_unique_names = TaxonName.all(:include => :taxon, 
      :conditions => {:name => name}, :select => "DISTINCT ON (taxon_id) *")
    non_unique_names.each do |taxon_name|
      taxon_name.taxon.update_unique_name if taxon_name.taxon
    end
    true
  end
  
  def self.choose_common_name(taxon_names)
    return nil if taxon_names.blank?
    common_names = taxon_names.reject { |tn| tn.is_scientific_names? }
    return nil if common_names.blank?
    common_names = common_names.sort_by(&:id)
    
    language_name = language_for_locale || 'english'
    locale_names = common_names.select {|n| n.lexicon.to_s.downcase == language_name}
    engnames = common_names.select {|n| n.is_english?}
    unknames = common_names.select {|n| n.lexicon == 'unspecified'}
    
    if locale_names.length > 0
      locale_names.first
    elsif engnames.length > 0
      engnames.first
    elsif unknames.length > 0
      unknames.first
    else
      common_names.first
    end
  end

  def self.language_for_locale(locale = nil)
    locale ||= I18n.locale
    lang_code = locale.to_s.split('-').first.to_s.downcase
    case lang_code
    when 'es' then return 'spanish'
    when 'fr' then return 'french'
    else
      return 'english'
    end
  end
  
  def self.choose_scientific_name(taxon_names)
    return nil if taxon_names.blank?
    taxon_names.select { |tn| tn.is_valid? && tn.is_scientific_names? }.first
  end
  
  def self.choose_default_name(taxon_names)
    return nil if taxon_names.blank?
    name = choose_common_name(taxon_names)
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
      taxon_names = TaxonName.all(:conditions => conditions, :limit => 10, :include => :taxon)
    rescue ActiveRecord::StatementInvalid => e
      raise e unless e.message =~ /invalid byte sequence/
      conditions[:name] = name.encode('UTF-8')
      taxon_names = TaxonName.all(:conditions => conditions, :limit => 10, :include => :taxon)
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
