class TaxonChange < ActiveRecord::Base
  belongs_to :taxon
  has_many :taxon_change_taxa, :dependent => :destroy
  has_many :taxa, :through => :taxon_change_taxa
  belongs_to :source
  has_many :comments, :as => :parent, :dependent => :destroy
  belongs_to :user
  belongs_to :committer, :class_name => 'User'

  has_subscribers
  after_update :notify_users_of_input_taxa_later
  
  validates_presence_of :taxon_id
  accepts_nested_attributes_for :source
  accepts_nested_attributes_for :taxon_change_taxa
  
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

  def notify_users_of_input_taxa_later
    return true unless committed_on_changed? && committed?
    delay(:priority => 1).notify_users_of_input_taxa
    true
  end

  def notify_users_of_input_taxa
    # return true unless committed_on_changed? && committed?
    taxon_ids = input_taxa.map(&:id)
    return true if taxon_ids.blank?
    has_many_reflections = User.reflections.select{|k,v| v.macro == :has_many}
    user_ids = Set.new
    has_many_reflections.map do |k, reflection|
      # Avoid those pesky :through relats
      next unless reflection.klass.column_names.include?(reflection.foreign_key)
      next unless reflection.klass.column_names.include?('taxon_id')
      user_ids += User.select("users.id").
        joins(reflection.name).
        where("#{reflection.table_name}.taxon_id IN (#{taxon_ids.join(',')})").
        map(&:id)
    end.compact
    user_ids.to_a.in_groups_of(500) do |batch|
      User.where("id IN (?)", batch.compact).each do |user|
        Update.create(
          :resource => self, 
          :notifier => self,
          :subscriber => user, 
          :notification => "committed")
      end
    end
    true
  end

end
