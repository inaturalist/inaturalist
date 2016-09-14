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
  validate :uniqueness_of_taxa
  validate :taxa_below_order
  accepts_nested_attributes_for :source
  accepts_nested_attributes_for :taxon_change_taxa, :allow_destroy => true,
    :reject_if => lambda { |attrs| attrs[:taxon_id].blank? }
  
  TAXON_JOINS = [
    "LEFT OUTER JOIN taxon_change_taxa tct ON tct.taxon_change_id = taxon_changes.id",
    "LEFT OUTER JOIN taxa t1 ON taxon_changes.taxon_id = t1.id",
    "LEFT OUTER JOIN taxa t2 ON tct.taxon_id = t2.id"
  ]

  TYPES = %w(TaxonChange TaxonMerge TaxonSplit TaxonSwap TaxonDrop TaxonStage)
  
  scope :types, lambda {|types| where("taxon_changes.type IN (?)", types)}
  scope :committed, -> { where("committed_on IS NOT NULL") }
  scope :uncommitted, -> { where("committed_on IS NULL") }
  scope :change_group, lambda {|group| where("change_group = ?", group)}
  scope :iconic_taxon, lambda {|iconic_taxon|
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

  scope :by, lambda{|user| where(:user_id => user)}
  
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
  def commit_records( options = {} )
    unless valid?
      Rails.logger.error "[ERROR #{Time.now}] Failed to commit records for #{self}: #{errors.full_messages.to_sentence}"
      return
    end
    return if input_taxa.blank?
    Rails.logger.info "[INFO #{Time.now}] starting commit_records for #{self}"
    notified_user_ids = []
    associations_to_update = %w(observations listed_taxa taxon_links identifications)
    has_many_reflections = associations_to_update.map do |a| 
      Taxon.reflections.detect{|k,v| k.to_s == a}
    end
    has_many_reflections.each do |k, reflection|
      reflection.klass.where("#{reflection.foreign_key} IN (?)", input_taxa.to_a.compact.map(&:id)).find_each do |record|
        record_has_user = record.respond_to?(:user) && record.user
        if !options[:skip_updates] && record_has_user && !notified_user_ids.include?(record.user.id)
          action_attrs = {
            resource: self,
            notifier: self,
            notification: "committed"
          }
          action = UpdateAction.first_with_attributes(action_attrs, skip_indexing: true)
          action.bulk_insert_subscribers( [record.user.id] )
          UpdateAction.elastic_index!(ids: [action.id])
          notified_user_ids << record.user.id
        end
        if automatable? && (!record_has_user || record.user.prefers_automatic_taxonomic_changes?)
          update_records_of_class(record.class, output_taxon, :records => [record])
        end
      end
    end
    [input_taxa, output_taxa].flatten.compact.each do |taxon|
      Taxon.where(id: taxon.id).update_all(
        observations_count: Observation.of(taxon).count,
        listed_taxa_count: ListedTaxon.where(:taxon_id => taxon).count)
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
      scope = klass.send(@klass.name.underscore.pluralize).where("#{klass.table_name}.taxon_id IN (?)", input_taxa)
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

  # This is an emergency tool, so for the love of Linnaeus please be careful
  # with it and don't expose it in the UI. It will correctly revert
  # identifications and observations, but for splits it will not do anything
  # for affected listed taxa or taxon links, and for other changes it will
  # assume records updated 24 hours after the change was committed were
  # updated by this change, which is obviously dubious.
  def partial_revert(debug = false)
    Rails.logger.info "[INFO #{Time.now}] Starting partial revert for #{self}"
    Rails.logger.info "[INFO #{Time.now}] Destroying identifications..."
    identifications.destroy_all unless debug
    in_taxon = input_taxa.first if input_taxa.size == 1
    if in_taxon
      listed_taxa_sql = <<-SQL
        UPDATE listed_taxa SET taxon_id = #{in_taxon.id} FROM places WHERE
          AND listed_taxa.taxon_id IN (#{output_taxa.map(&:id).join(',')})
          AND (listed_taxa.updated_at BETWEEN '#{(committed_on+0.hours).to_s(:db)}' AND '#{(committed_on+1.day).to_s(:db)}')
      SQL
      Rails.logger.info "[INFO #{Time.now}] Reverting listed taxa: #{listed_taxa_sql}"
      ActiveRecord::Base.connection.execute(listed_taxa_sql) unless debug
      taxon_link_sql = <<-SQL
        UPDATE taxon_links SET taxon_id = #{in_taxon.id} FROM places WHERE
          AND taxon_links.taxon_id IN (#{output_taxa.map(&:id).join(',')})
          AND (taxon_links.updated_at BETWEEN '#{(committed_on+0.hours).to_s(:db)}' AND '#{(committed_on+1.day).to_s(:db)}')
      SQL
      Rails.logger.info "[INFO #{Time.now}] Reverting taxon links: #{taxon_link_sql}"
      ActiveRecord::Base.connection.execute(taxon_link_sql) unless debug
    end
    Rails.logger.info "[INFO #{Time.now}] Finished partial revert for #{self}"
  end

  def automatable?
    output_taxa.size == 1
  end

  def commit_records_later
    return true unless committed_on_changed? && committed?
    delay(:priority => USER_PRIORITY).commit_records
    true
  end

  def editable_by?(u)
    return false if u.blank?
    return true if u.is_curator?
    return true if u.id == user_id
    false
  end

  def uniqueness_of_taxa
    taxon_ids = [taxon_id, taxon_change_taxa.map(&:taxon_id)].flatten.compact
    if taxon_ids.size != taxon_ids.uniq.size
      errors.add(:base, "input and output taxa must be unique")
    end
  end

  def taxa_below_order
    return true if user && user.is_admin?
    if [taxon, taxon_change_taxa.map(&:taxon)].flatten.compact.detect{|t| t.rank_level >= Taxon::ORDER_LEVEL }
      errors.add(:base, "only admins can move around taxa at order-level and above")
    end
    true
  end

  def move_input_children_to_output( target_input_taxon )
    unless target_input_taxon.is_a?( Taxon )
      target_input_taxon = Taxon.find_by_id( target_input_taxon )
    end
    if target_input_taxon.rank_level <= Taxon::GENUS_LEVEL && output_taxon.rank == target_input_taxon.rank
      target_input_taxon.children.active.each do |child|
        tc = TaxonSwap.new(
          user: user,
          change_group: (change_group || "#{self.class.name}-#{id}-children"),
          source: source,
          description: "Automatically generated change from #{FakeView.taxon_change_url( self )}"
        )
        tc.add_input_taxon( child )
        output_child_name = child.name.sub( target_input_taxon.name, output_taxon.name)
        unless output_child = output_taxon.children.detect{|c| c.name == output_child_name }
          output_child = Taxon.new(
            name: output_child_name,
            rank: child.rank,
            is_active: false
          )
          output_child.save!
          output_child.update_attributes( parent: output_taxon )
        end
        tc.add_output_taxon( output_child )
        tc.save!
        tc.commit
      end
    else
      target_input_taxon.children.active.each { |child| child.move_to_child_of( output_taxon ) }
    end
  end

end
