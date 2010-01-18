class TaxonName < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :source
  belongs_to :creator, :class_name => 'User'
  belongs_to :updater, :class_name => 'User'
  validates_presence_of :taxon
  validates_associated :taxon
  validates_length_of :name, :within => 1..256
  validates_uniqueness_of :name, 
                          :scope => [:lexicon, :taxon_id], 
                          :message => "already exists for this taxon in this lexicon"
  before_validation :strip_name, :remove_rank_from_name, :normalize_lexicon
  before_validation do |tn|
    tn.name = tn.name.capitalize if tn.lexicon == LEXICONS[:SCIENTIFIC_NAMES]
  end
  after_create {|name| name.taxon.set_scientific_taxon_name}
  after_save :update_unique_names
  after_destroy {|name| name.taxon.update_unique_name if name.taxon}
  
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
    :ILOKANO             =>  'Ilokano',
    :ITALIAN             =>  'Italian',
    :KOREAN              =>  'Korean',
    :MALTESE             =>  'Maltese',
    :MAORI               =>  'Maori',
    :MISIMA_PANEATI      =>  'Misima-paneati',
    :NORWEGIAN           =>  'Norwegian',
    :PANGASINAN          =>  'Pangasinan',
    :PORTUGUESE          =>  'Portuguese',
    :RUMANIAN            =>  'Rumanian',
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
    LEXICONS[:ENGLISH]
  ]
  
  LEXICONS.keys.each do |language|
    class_eval <<-EOT
      def is_#{language.to_s.downcase}?
        lexicon == LEXICONS[:#{language}]
      end
    EOT
  end
  
  def to_s
    "<TaxonName #{self.id}: #{self.name} in #{self.lexicon}>"
  end
  
  def strip_name
    self.name.strip! if self.name
  end
  
  def remove_rank_from_name
    return unless self.lexicon == LEXICONS[:SCIENTIFIC_NAMES]
    self.name = Taxon.remove_rank_from_name(self.name)
  end
  
  def normalize_lexicon
    return true if lexicon.blank?
    self.lexicon = LEXICONS[lexicon.upcase.to_sym] if LEXICONS[lexicon.upcase.to_sym]
  end
  
  def update_unique_names
    return true unless name_changed?
    non_unique_names = TaxonName.all(:include => :taxon, 
      :conditions => {:name => name}, :group => :taxon_id)
    non_unique_names.each do |taxon_name|
      taxon_name.taxon.update_unique_name if taxon_name.taxon
    end
    true
  end
end
