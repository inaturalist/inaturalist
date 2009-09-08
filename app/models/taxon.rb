class Taxon < ActiveRecord::Base
  # Sometimes you don't want to make a new taxon name with a taxon, like when
  # you're saving a new taxon name with a new associated taxon. Hence, this.
  attr_accessor :skip_new_taxon_name
  
  # If you want to shove some HTML in there before creating some JSON...
  attr_accessor :html
  
  acts_as_flaggable
  
  acts_as_nested_set
  # memoize :ancestors TODO in rails 2.3
  acts_as_versioned :if_changed => [:name, :rank, :iconid_taxon_id, 
                                    :parent_id, :source_id, 
                                    :source_identifier, :source_url, 
                                    :is_iconic, :auto_photos, 
                                    :auto_description, :name_provider]
  self.non_versioned_columns += 
    %w"observations_count listed_taxa_count lft rgt delta"
  has_many :child_taxa, :class_name => Taxon.to_s, :foreign_key => :parent_id
  has_many :taxon_names, :dependent => :destroy
  has_many :observations
  has_many :listed_taxa, :dependent => :destroy
  has_many :lists, :through => :listed_taxa
  has_many :places, :through => :listed_taxa
  has_many :identifications, :dependent => :destroy
  has_many :taxon_links, :dependent => :destroy 
  belongs_to :source
  belongs_to :iconic_taxon, :class_name => 'Taxon', 
                            :foreign_key => 'iconic_taxon_id'
  belongs_to :creator, :class_name => 'User'
  belongs_to :updater, :class_name => 'User'
  has_and_belongs_to_many :flickr_photos, :uniq => true
  has_and_belongs_to_many :colors
  
  define_index do
    indexes taxon_names.name, :as => :names
    indexes colors.value, :as => :color_values
    indexes iconic_taxon.taxon_names.name, :as => :iconic_taxon_names
    has iconic_taxon_id, :facet => true, :type => :integer
    # has colors, :as => :color, :type => :multi, :facet => true # if colors were a column of CSV integers
    has colors(:id), :as => :colors, :facet => true, :type => :multi
    has listed_taxa(:place_id), :as => :places, :facet => true, :type => :multi
    has created_at
    set_property :delta => true
  end
  
  before_validation :normalize_rank, :set_rank_level, :remove_rank_from_name
  before_save :set_iconic_taxon # if after, it would require an extra save
  before_save {|taxon| taxon.name = taxon.name.capitalize}
  after_move :update_listed_taxa, :set_iconic_taxon_and_save
  after_create :create_matching_taxon_name
  
  validates_associated :flickr_photos
  validates_presence_of :name, :rank
  validates_uniqueness_of :name, 
                          :scope => [:parent_id],
                          :unless => Proc.new { |taxon| taxon.parent_id.nil? },
                          :message => "already used as a child of this " + 
                                      "taxon's parent"
  
  NAME_PROVIDER_TITLES = {
    'ColNameProvider' => 'Catalogue of Life',
    'UBioNameProvider' => 'uBio'
  }
  
  RANK_LEVELS = {
    'root'         => 100,
    'kingdom'      => 70,
    'phylum '      => 60,
    'subphylum'    => 57,
    'superclass'   => 53,
    'class'        => 50,
    'sublcass'     => 47,
    'superorder'   => 43,
    'order'        => 40,
    'suborder'     => 37,
    'superfamily'  => 33,
    'family'       => 30,
    'subfamily'    => 27,
    'supertribe'   => 26,
    'tribe'        => 25,
    'subtribe'     => 24,
    'genus'        => 20,
    'species'      => 10,
    'subspecies'   => 5,
    'variety'      => 5
  }
  
  RANKS = RANK_LEVELS.keys
  
  RANK_EQUIVALENTS = {
    'sub-class'       => 'subclass',
    'super-order'     => 'superorder',
    'infraorder'      => 'suborder',
    'sub-order'       => 'suborder',
    'super-family'    => 'superfamily',
    'sub-family'      => 'subfamily',
    'gen'             => 'genus',
    'sp'              => 'species',
    'infraspecies'    => 'subspecies',
    'ssp'             => 'subspecies',
    'sub-species'     => 'subspecies',
    'subsp'           => 'subspecies',
    'trinomial'       => 'subspecies',
    'var'             => 'variety',
    'unranked'        => nil
  }
  
  PREFERRED_RANKS = [
    'kingdom',
    'phylum',
    'class',
    'order',
    'superfamily',
    'family',
    'genus',
    'species',
    'subspecies',
    'variety'
  ]
  
  # In case you don't feel like looking up TaxonNames
  ICONIC_TAXON_NAMES = {
    'Animalia' => 'Animals',
    'Actinopterygii' => 'Ray-finned Fishes',
    'Aves' => 'Birds',
    'Reptilia' => 'Reptiles',
    'Amphibia' => 'Amphibians',
    'Mammalia' => 'Mammals',
    'Arachnida' => 'Arachnids',
    'Insecta' => 'Insects',
    'Plantae' => 'Plants',
    'Fungi' => 'Fungi',
    'Protozoa' => 'Protozoans',
    'Mollusca' => 'Mollusks'
  }
  
  ICONIC_TAXON_DISPLAY_NAMES = ICONIC_TAXON_NAMES.merge(
    'Animalia' => 'Other Animals'
  )
  
  # see the end for the validate method
  def to_s
    "<Taxon #{self.id}: #{self.to_plain_s}>"
  end
  
  def to_plain_s
    comname = self.common_name
    if self.rank == 'species' or self.rank == 'infraspecies'
      sciname = self.name
    else
      sciname = '%s %s' % [self.rank.capitalize, self.name]
    end
    if comname.nil?
      return sciname
    else
      return '%s (%s)' % [comname.name, sciname]
    end
  end
  
  named_scope :observed_by, lambda {|user|
    { :joins => """
      JOIN (
        SELECT
          taxon_id
        FROM
          observations
        WHERE
          user_id=#{user.id}
        GROUP BY taxon_id
      ) o
      ON o.taxon_id=#{Taxon.table_name}.#{Taxon.primary_key}
      """ }}
  
  named_scope :iconic_taxa, :conditions => "is_iconic = true",
    :include => [:taxon_names]
  
  def observations_count_with_descendents
    Observation.of(self).count
  end
  
  def self.occurs_in(minx, miny, maxx, maxy, startdate=nil, enddate=nil)
    startdate = startdate.nil? ? 100.years.ago.to_date : Date.parse(startdate) # wtf, only 100 years?!
    enddate = enddate.nil? ? Time.now.to_date : Date.parse(enddate)
    startdate = startdate.to_param
    enddate = enddate.to_param
    sql = """
      SELECT 
        t.*,
        o.count as count
      FROM
        col_taxa t
          JOIN 
            (SELECT 
                taxon_id, count(*) as count
              FROM observations 
              WHERE 
                observed_on > '#{startdate}' AND observed_on < '#{enddate}' AND
                latitude > '#{miny}' AND 
                longitude > '#{minx}' AND 
                latitude < '#{maxy}' AND 
                longitude < '#{maxx}'
              GROUP BY taxon_id) o
            ON o.taxon_id=t.record_id
    """
    Taxon.find_by_sql(sql)
  end
  
  #
  # Count the number of taxa in the given rank.
  #
  # I don't like hard-coding it like this, so if you know an abstract way of 
  # getting at the column name associated with an attribute, or an aliased 
  # attribute like 'rank', please tell me.
  #
  def self.count_taxa_in_rank(rank)
    Taxon.count_by_sql(
      "SELECT COUNT(*) from #{Taxon.table_name} WHERE (rank = '#{rank.downcase}')"
    )
  end
  
  #
  # Test whether this taxon's range overlaps a place
  #
  # def range_overlaps?(place)
  #   # looks like georuby doesn't support intersection just yet, probably 
  #   # because MySQL only supports intersections of minimum bounding 
  #   # rectangles.  Kinda stupid...
  #   self.range.geom.intersects? place.geom
  # end
  
  #
  # Test whether this taxon is in another taxon (e.g. Anna's Humminbird is in 
  # Class Aves)
  #
  def in_taxon?(taxon)
    self.lft > taxon.lft && self.rgt < taxon.rgt
  end
  
  def grafted?
    return false if new_record? # New records haven't been grafted
    return false if self.name != 'Life' && self.root?
    true
  end
  
  def default_name
    return common_name if common_name
    return scientific_name if scientific_name
    taxon_names.first
  end
  
  def scientific_name
    taxon_names.all.select do |tn|
      tn.is_valid? && tn.is_scientific_names?
    end.first
  end
  
  #
  # Return just one common name.  Defaults to the first English common name, 
  # then first name of unspecified language (not-not-English), then the first 
  # common name of any language failing that
  #
  def common_name
    common_names = taxon_names.all.select do |tn| 
      !tn.is_scientific_names?
    end
    return nil if common_names.blank?
    
    engnames = common_names.select do |n| 
      n.is_english?
    end
    unknames = common_names.select do |n| 
      n.name if n.lexicon == 'unspecified'
    end
    
    if engnames.length > 0
      engnames.first
    elsif unknames.length > 0
      unknames.first
    else
      common_names.first
    end
  end
  
  
  #
  # Set the iconic taxon if it hasn't been set
  #
  def set_iconic_taxon
    logger.debug("[DEBUG] Setting iconic taxon for #{self.name}...")
    if self.is_iconic?
      self.iconic_taxon = self
    else
      self.iconic_taxon = ancestors.reverse.select {|a| a.is_iconic?}.first
    end
    
    if iconic_taxon_id_changed?
      logger.debug "[DEBUG] \t iconic taxon changed, updating descendants and their observations..."
      # Update the iconic taxon of all descendants that currently have an iconic
      # taxon that is an ancestor (i.e. don't touch descendant iconic taxa)
      self.descendants.update_all(
        "iconic_taxon_id = #{iconic_taxon_id || 'NULL'}", 
        ["iconic_taxon_id IN (?) OR iconic_taxon_id IS NULL", 
          self.ancestors.all])

      # Do the same for observations
      Observation.update_all(
        "iconic_taxon_id = #{iconic_taxon_id || 'NULL'}", 
        ["id IN (?) AND (iconic_taxon_id IN (?) OR iconic_taxon_id IS NULL)", 
          Observation.of(self), 
          self.ancestors.all])
    end
  end
  
  def set_iconic_taxon_and_save
    set_iconic_taxon
    save
  end
  
  #
  # Create a scientific taxon name matching this taxon's name if one doesn't
  # already exist.
  #
  def set_scientific_taxon_name
    unless self.taxon_names.find(:first, 
      :conditions => ["name = ?", self.name])
      self.taxon_names << TaxonName.create(
        :name => self.name,
        :source => self.source,
        :source_identifier => self.source_identifier,
        :source_url => self.source_url,
        :lexicon => 'scientific names',
        :is_valid => true
      )
    end
  end
  
  #
  # Checks whether this taxon has been flagged
  #
  def flagged?
    self.flags.select { |f| not f.resolved? }.size > 0
  end
  
  #
  # Fetches associated user-selected FlickrPhotos if they exist, otherwise
  # gets the the first :limit Create Commons-licensed photos tagged with the
  # taxon's scientific name from Flickr.  So this will return a heterogeneous
  # array: part FlickrPhotos, part net::flickr Photos
  #
  def photos(params = {})
    params[:limit] ||= 9
    photos = self.flickr_photos[0..params[:limit]-1]
    flickr_photos = []
    if photos.size < params[:limit] and self.auto_photos
      begin
        netflickr = Net::Flickr.authorize(FLICKR_API_KEY, FLICKR_SHARED_SECRET)
        flickr_photos = netflickr.photos.search({
          :tags => self.name.gsub(' ', '').strip,
          :per_page => params[:limit] - photos.size,
          :license => '1,2,3,4,5,6', # CC licenses
          :extras => 'date_upload,owner_name'
        }).to_a
      rescue Net::Flickr::APIError => e
        logger.error "EXCEPTION RESCUE: #{e}"
        logger.error e.backtrace.join("\n\t")
      end
    end
    flickr_ids = photos.map(&:flickr_native_photo_id)
    photos += flickr_photos.reject do |fp|
      flickr_ids.include?(fp.id)
    end
    photos
  end
  
  def phylum
    ancestors.find(:first, :conditions => "rank = 'phylum'")
  end
  

  def validate
    # logger.info("DEBUG: Validating non-circularity for #{self.name}...")
    if self.parent == self
      # logger.info("DEBUG: Gah, #{self.name} can't be its own parent!")
      errors.add(self.name, "can't be its own parent")
    end
    if self.ancestors and self.ancestors.include? self
      # logger.info("DEBUG: Gah, #{self.name} can't be one of its own ancestors!")
      errors.add(self.name, "can't be its own ancestor")
    end
  end
  
  def indexed_self_and_ancestors(params = {})
    params = params.merge({
      :from => "`#{Taxon.table_name}` FORCE INDEX (index_taxa_on_lft_and_rgt)", 
      :conditions => ["`lft` <= ? AND `rgt` >= ?", self.lft, self.rgt]
    })
    Taxon.all(params)
  end
  
  #
  # Determine whether this taxon is at or below the rank of species
  #
  def species_or_lower?
    %w"species subspecies variety infraspecies".include?(self.rank.downcase)
  end
  
  # Updated the "cached" lft values in all listed taxa with this taxon
  def update_listed_taxa
    ancestor_ids = self.ancestors.all(:select => 'id').map(&:id).join(',')
    ListedTaxon.update_all(
      "lft = #{self.lft}, taxon_ancestor_ids = '#{ancestor_ids}'", 
      "taxon_id = #{self.id}")
  end
  
  # Create a taxon name with the same name as this taxon
  def create_matching_taxon_name
    if @skip_new_taxon_name
      return
    end
    
    taxon_attributes = self.attributes
    taxon_attributes.delete('id')
    tn = TaxonName.new
    taxon_attributes.each do |k,v|
      tn[k] = v if TaxonName.column_names.include?(k)
    end
    tn.lexicon = TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
    tn.is_valid = true
    
    self.taxon_names << tn
  end
  
  def self.normalize_rank(rank)
    return rank if rank.nil?
    rank = rank.gsub(/[^\w]/, '').downcase
    return rank if RANKS.include?(rank)
    return RANK_EQUIVALENTS[rank] if RANK_EQUIVALENTS[rank]
    rank
  end
  
  def normalize_rank
    self.rank = Taxon.normalize_rank(self.rank)
  end
  
  def set_rank_level
    self.rank_level = RANK_LEVELS[self.rank]
  end
  
  def self.remove_rank_from_name(name)
    pieces = name.split
    return name if pieces.size == 1
    pieces.map! {|p| p.gsub(/[^\w]/, '')}
    pieces.reject! {|p| (RANKS + RANK_EQUIVALENTS.keys).include?(p.downcase)}
    pieces.join(' ')
  end
  
  def remove_rank_from_name
    self.name = Taxon.remove_rank_from_name(self.name)
  end
  
  def lsid
    "lsid:inaturalist.org:taxa:#{id}"
  end
  
  # Flagged method is called after every add_flag.  This callback method
  # is totally optional and does not have to be included in the model
  def flagged(flag, flag_count)
      true
  end
  
  include TaxaHelper
  def image_url
    taxon_image_url(self)
  end
end
