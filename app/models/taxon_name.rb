class TaxonName < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :source
  belongs_to :creator, :class_name => 'User'
  belongs_to :updater, :class_name => 'User'
  validates_presence_of :taxon
  validates_associated :taxon
  validates_uniqueness_of :name, 
                          :scope => [:lexicon, :taxon_id], 
                          :message => "already exists for this taxon in this lexicon"
  before_validation :strip_name, :remove_rank_from_name
  before_validation do |tn|
    tn.name = tn.name.capitalize if tn.lexicon == LEXICONS[:SCIENTIFIC_NAMES]
  end
  after_create {|name| name.taxon.set_scientific_taxon_name}
  
  LEXICONS = {
    :SCIENTIFIC_NAMES    =>  'scientific names',
    :AFRIKAANS           =>  'afrikaans',
    :BENGALI             =>  'bengali',
    :CEBUANO             =>  'cebuano',
    :CREOLE_FRENCH       =>  'creole, french',
    :CREOLE_PORTUGUESE   =>  'creole, portuguese',
    :DAVAWENYO           =>  'davawenyo',
    :DUTCH               =>  'dutch',
    :ENGLISH             =>  'english',
    :FRENCH              =>  'french',
    :GELA                =>  'gela',
    :GERMAN              =>  'german',
    :HAWAIIAN            =>  'hawaiian',
    :HEBREW              =>  'hebrew',
    :HILIGAYNON          =>  'hiligaynon',
    :ILOKANO             =>  'ilokano',
    :ITALIAN             =>  'italian',
    :KOREAN              =>  'korean',
    :MALTESE             =>  'maltese',
    :MISIMA_PANEATI      =>  'misima-paneati',
    :NORWEGIAN           =>  'norwegian',
    :PANGASINAN          =>  'pangasinan',
    :PORTUGUESE          =>  'portuguese',
    :RUMANIAN            =>  'rumanian',
    :SPANISH             =>  'spanish',
    :SWEDISH             =>  'swedish',
    :TAGALOG             =>  'tagalog',
    :TAHITIAN            =>  'tahitian',
    :TOKELAUAN           =>  'tokelauan',
    :TURKISH             =>  'turkish',
    :WARAY_WARAY         =>  'waray-waray'
  }
  
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
end
