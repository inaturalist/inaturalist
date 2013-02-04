class TaxonChange < ActiveRecord::Base
  belongs_to :taxon
  has_many :taxon_change_taxa, :dependent => :destroy
  has_many :taxa, :through => :taxon_change_taxa
  belongs_to :source
  has_many :comments, :as => :parent, :dependent => :destroy
  has_many :identifications, :dependent => :nullify
  belongs_to :user
  belongs_to :committer, :class_name => 'User'

  has_subscribers
  after_update :commit_records_later
  
  validates_presence_of :taxon_id
  accepts_nested_attributes_for :source
  accepts_nested_attributes_for :taxon_change_taxa, :allow_destroy => true,
    :reject_if => lambda { |attrs| attrs[:taxon_id].blank? }
  
  TAXON_JOINS = [
    "LEFT OUTER JOIN taxon_change_taxa tct ON tct.taxon_change_id = taxon_changes.id",
    "LEFT OUTER JOIN taxa t1 ON taxon_changes.taxon_id = t1.id",
    "LEFT OUTER JOIN taxa t2 ON tct.taxon_id = t2.id"
  ]

  TYPES = %w(TaxonChange TaxonMerge TaxonSplit TaxonSwap TaxonDrop TaxonStage)
  
  scope :types, lambda {|types| where("type IN (?)", types)}
  scope :committed, where("committed_on IS NOT NULL")
  scope :uncommitted, where("committed_on IS NULL")
  scope :change_group, lambda{|group| where("change_group = ?", group)}
  scope :iconic_taxon, lambda{|iconic_taxon|
    joins(TAXON_JOINS).
    where("t1.iconic_taxon_id = ? OR t2.iconic_taxon_id = ?", iconic_taxon, iconic_taxon)
  }
  scope :source, lambda{|source|
    joins(TAXON_JOINS).
    where("t1.source_id = ? OR t2.source_id = ?", source, source)
  }
  
  scope :taxon, lambda{|taxon|
    joins(TAXON_JOINS).
    where("t1.id = ? OR t2.id = ?", taxon, taxon)
  }
  
  scope :input_taxon, lambda{|taxon|
    joins(TAXON_JOINS).
    where(
      "(taxon_changes.type IN ('TaxonSwap', 'TaxonMerge') AND t2.id = ?) OR " +
      "(taxon_changes.type IN ('TaxonSplit', 'TaxonDrop', 'TaxonStage') AND taxon_changes.taxon_id = ?)", 
      taxon, taxon
    )
  }
  
  scope :output_taxon, lambda{|taxon|
    joins(TAXON_JOINS).
    where(
      "(taxon_changes.type IN ('TaxonSwap', 'TaxonMerge') AND taxon_changes.taxon_id = ?) OR " +
      "(taxon_changes.type = 'TaxonSplit' AND t2.id = ?)", 
      taxon, taxon
    )
  }
  
  scope :taxon_scheme, lambda{|taxon_scheme|
    joins(TAXON_JOINS).
    joins(
      "LEFT OUTER JOIN taxon_scheme_taxa tst1 ON tst1.taxon_id = t1.id",
      "LEFT OUTER JOIN taxon_scheme_taxa tst2 ON tst2.taxon_id = t2.id",
      "LEFT OUTER JOIN taxon_schemes ts1 ON ts1.id = tst1.taxon_scheme_id",
      "LEFT OUTER JOIN taxon_schemes ts2 ON ts2.id = tst2.taxon_scheme_id"
    ).
    where("ts1.id = ? OR ts2.id = ?", taxon_scheme, taxon_scheme)
  }
  
  def to_s
    "<#{self.class} #{id}>"
  end
  
  def committed?
    !committed_on.blank?
  end

  # Override in subclasses that use self.taxon_change_taxa as the input
  def add_input_taxon(taxon)
    self.taxon = taxon
  end

  # Override in subclasses that use self.taxon as the output
  def add_output_taxon(taxon)
    self.taxon_change_taxa.build(:taxon => taxon, :taxon_change => self)
  end

  def input_taxa
    [taxon]
  end

  def output_taxa
    taxa
  end

  def verb_phrase
    "#{self.class.name.underscore.split('_')[1..-1].join(' ').downcase}"
  end

  # Override in subclasses
  def commit
    input_taxa.each {|t| t.update_attribute(:is_active, false)}
    output_taxa.each {|t| t.update_attribute(:is_active, true)}
    update_attribute(:committed_on, Time.now)
  end

  # For all records with a taxon association affected by this change, update the record if 
  # possible / desired by its owner, or generate an update for the owner notifying them of 
  # the change
  def commit_records
    return if input_taxa.blank?
    Rails.logger.info "[INFO #{Time.now}] starting commit_records for #{self}"
    notified_user_ids = []
    associations_to_update = %w(observations listed_taxa taxon_links identifications)
    has_many_reflections = associations_to_update.map do |a| 
      Taxon.reflections.detect{|k,v| k.to_s == a}
    end
    has_many_reflections.each do |k, reflection|
      reflection.klass.where("#{reflection.foreign_key} IN (?)", input_taxa).find_each do |record|
        record_has_user = record.respond_to?(:user) && record.user
        if record_has_user && !notified_user_ids.include?(record.user.id)
          Update.create(
            :resource => self,
            :notifier => self,
            :subscriber => record.user, 
            :notification => "committed")
          notified_user_ids << record.user.id
        end
        if automatable? && (!record_has_user || record.user.prefers_automatic_taxonomic_changes?)
          update_records_of_class(record.class, output_taxon, :records => [record])
        end
      end
    end
    [input_taxa, output_taxa].flatten.compact.each do |taxon|
      Taxon.update_all(
        [
          "observations_count = ?, listed_taxa_count = ?", 
          Observation.where(:taxon_id => taxon).count, 
          ListedTaxon.where(:taxon_id => taxon).count
        ],
        ["id = ?", taxon.id]
      )
    end
    Rails.logger.info "[INFO #{Time.now}] finished commit_records for #{self}"
  end

  # Change all records associated with input taxa to use the selected taxon
  def update_records_of_class(klass, taxon, options = {}, &block)
    if klass.respond_to?(:update_for_taxon_change)
      klass.update_for_taxon_change(self, taxon, options, &block)
      return
    end
    records = if options[:records]
      options[:records]
    else
      scope = klass.send(@klass.name.underscore.pluralize).where("#{klass.table_name}.taxon_id IN (?)", input_taxa).scoped
      scope = scope.where("user_id = ?", options[:user]) if options[:user]
      scope = scope.where(options[:conditions]) if options[:conditions]
      scope = scope.includes(options[:include]) if options[:include]
      scope
    end
    proc = Proc.new do |record|
      record.update_attributes(:taxon => taxon)
      yield(record) if block_given?
    end
    if records.respond_to?(:find_each)
      records.find_each(&proc)
    else
      records.each(&proc)
    end
  end

  def automatable?
    output_taxa.size == 1
  end

  def commit_records_later
    return true unless committed_on_changed? && committed?
    delay(:priority => NOTIFICATION_PRIORITY).commit_records
    true
  end

  def editable_by?(u)
    return false if u.blank?
    return true if u.is_curator?
    return true if u.id == user_id
    false
  end

end
