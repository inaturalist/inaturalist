class TaxonChange < ActiveRecord::Base
  belongs_to :taxon, inverse_of: :taxon_changes
  has_many :taxon_change_taxa, inverse_of: :taxon_change, dependent: :destroy
  has_many :taxa, :through => :taxon_change_taxa
  belongs_to :source
  has_many :comments, :as => :parent, :dependent => :destroy
  has_many :identifications, :dependent => :nullify
  belongs_to :user
  belongs_to :committer, :class_name => 'User'

  has_subscribers
  after_create :index_taxon
  after_destroy :index_taxon
  after_update :commit_records_later
  
  validates_presence_of :taxon_id
  validate :uniqueness_of_taxa
  validate :taxa_below_order
  accepts_nested_attributes_for :source
  accepts_nested_attributes_for :taxon_change_taxa, :allow_destroy => true,
    :reject_if => lambda { |attrs| attrs[:taxon_id].blank? }

  notifies_users :new_mentioned_users, on: :save, notification: "mention"
  
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

  def committable_by?( u )
    return false unless u
    return false unless u.is_curator?
    uneditable_input_taxon = input_taxa.detect{ |t| !t.protected_attributes_editable_by?( u ) }
    uneditable_output_taxon = nil
    unless uneditable_input_taxon
      uneditable_output_taxon = output_taxa.detect{ |t| !t.protected_attributes_editable_by?( u ) }
    end
    uneditable_input_taxon.blank? && uneditable_output_taxon.blank?
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
    [taxon].compact
  end

  def output_taxa
    taxa
  end

  def verb_phrase
    "#{self.class.name.underscore.split('_')[1..-1].join(' ').downcase}"
  end

  class PermissionError < StandardError; end

  # Override in subclasses
  def commit
    unless committable_by?( committer )
      raise PermissionError, "Committing user doesn't have permission to commit"
    end
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
    Rails.logger.info "[INFO #{Time.now}] #{self}: starting commit_records"
    notified_user_ids = []
    associations_to_update = %w(identifications observations listed_taxa taxon_links observation_field_values)
    has_many_reflections = associations_to_update.map do |a| 
      Taxon.reflections.detect{|k,v| k.to_s == a}
    end
    has_many_reflections.each do |k, reflection|
      Rails.logger.info "[INFO #{Time.now}] #{self}: committing #{k}"
      find_batched_records_of( reflection ) do |batch|
        auto_updatable_records = []
        Rails.logger.info "[INFO #{Time.now}] #{self}: committing #{k}, batch starting with #{batch[0]}" if options[:debug]
        batch.each do |record|
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
            auto_updatable_records << record
          end
        end
        Rails.logger.info "[INFO #{Time.now}] #{self}: committing #{k}, #{auto_updatable_records.size} automatable records" if options[:debug]
        unless auto_updatable_records.blank?
          update_records_of_class( reflection.klass, records: auto_updatable_records )
        end
      end
    end
    [input_taxa, output_taxa].flatten.compact.each do |taxon|
      Rails.logger.info "[INFO #{Time.now}] #{self}: updating counts for #{taxon}"
      Taxon.where(id: taxon.id).update_all(
        observations_count: Observation.of(taxon).count,
        listed_taxa_count: ListedTaxon.where(:taxon_id => taxon).count)
    end
    Rails.logger.info "[INFO #{Time.now}] #{self}: finished commit_records"
  end

  def find_batched_records_of( reflection )
    input_taxon_ids = input_taxa.to_a.compact.map(&:id)
    if reflection.klass == Observation
      Observation.search_in_batches( taxon_ids: input_taxon_ids ) do |batch|
        yield batch
      end
    # Omitting using ES for idents now until the ident index gets fully 
    # rebuilt. This should be slower but more reliable
    # elsif reflection.klass == Identification
    #   page = 1
    #   loop do
    #     results = Identification.elastic_paginate(
    #       filters: [
    #         { terms: { "taxon.ancestor_ids" => input_taxon_ids } },
    #         { term: { current: true } }
    #       ],
    #       page: page,
    #       per_page: 100
    #     )
    #     break if results.blank?
    #     yield results
    #     page += 1
    #   end
    elsif reflection.klass == Identification
      Identification.where( taxon_id: input_taxon_ids, current: true ).find_in_batches do |batch|
        yield batch
      end
    elsif reflection.klass == ObservationFieldValue
      ObservationFieldValue.
          joins(:observation_field).
          where( "value IN (?)", input_taxon_ids.map(&:to_s) ).
          find_in_batches do |batch|
        yield batch
      end
    else
      scope = reflection.klass.where( "#{reflection.foreign_key} IN (?)", input_taxon_ids )
      # sometimes reflections have custom scopes that need to be applied
      scope = scope.merge( reflection.scope ) if reflection.scope
      scope.find_in_batches do |batch|
        yield batch
      end
    end
  end

  # Change all records associated with input taxa to use the selected taxon
  def update_records_of_class(klass, options = {}, &block)
    if klass.respond_to?(:update_for_taxon_change)
      klass.update_for_taxon_change(self, options, &block)
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
      if taxon = options[:taxon] || output_taxon_for_record( record )
        record.update_attributes( taxon: taxon )
      end
      yield(record) if block_given?
    end
    if records.respond_to?(:find_each)
      records.find_each(&proc)
    else
      records.each(&proc)
    end
  end

  def output_taxon_for_record( record )
    output_taxa.first if output_taxa.size == 1
  end

  # This is an emergency tool, so for the love of Linnaeus please be careful
  # with it and don't expose it in the UI. It will correctly revert
  # identifications and observations, but for splits it will not do anything
  # for affected listed taxa or taxon links, and for other changes it will
  # assume records updated 24 hours after the change was committed were
  # updated by this change, which is obviously dubious.
  def partial_revert( options = {} )
    debug = options[:debug]
    logger = options[:logger] || Rails.logger
    logger.info "[INFO #{Time.now}] Starting partial revert for #{self}"
    logger.info "[INFO #{Time.now}] Destroying identifications..."
    unless debug
      identifications.find_each(&:destroy)
    end
    in_taxon = input_taxa.first if input_taxa.size == 1
    if in_taxon && !output_taxa.blank?
      listed_taxa_sql = <<-SQL
        UPDATE listed_taxa SET taxon_id = #{in_taxon.id} FROM places WHERE
          listed_taxa.taxon_id IN (#{output_taxa.map(&:id).join(',')})
          AND (listed_taxa.updated_at BETWEEN '#{(committed_on+0.hours).to_s(:db)}' AND '#{(committed_on+1.day).to_s(:db)}')
      SQL
      logger.info "[INFO #{Time.now}] Reverting listed taxa: #{listed_taxa_sql}"
      ActiveRecord::Base.connection.execute(listed_taxa_sql) unless debug
      taxon_link_sql = <<-SQL
        UPDATE taxon_links SET taxon_id = #{in_taxon.id} FROM places WHERE
          taxon_links.taxon_id IN (#{output_taxa.map(&:id).join(',')})
          AND (taxon_links.updated_at BETWEEN '#{(committed_on+0.hours).to_s(:db)}' AND '#{(committed_on+1.day).to_s(:db)}')
      SQL
      logger.info "[INFO #{Time.now}] Reverting taxon links: #{taxon_link_sql}"
      ActiveRecord::Base.connection.execute(taxon_link_sql) unless debug
    end
    input_taxa.each do |input_taxon|
      input_taxon.update_attributes( is_active: true )
    end
    # output taxa may or may not need to be made inactive, impossible to say in code
    logger.info "[INFO #{Time.now}] Finished partial revert for #{self}"
  end

  def automatable?
    output_taxa.size == 1
  end

  def commit_records_later
    return true unless committed_on_changed? && committed?
    delay(:priority => USER_INTEGRITY_PRIORITY).commit_records
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
    if [taxon, taxon_change_taxa.map(&:taxon)].flatten.compact.detect{|t| t.rank_level.to_i >= Taxon::ORDER_LEVEL }
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
        # If for some horrible reason people are swapping replacing taxa with
        # their own children, at least don't get into some kind of invite
        # change loop.
        if input_taxa.include?( child ) || output_taxa.include?( child )
          next
        end
        tc = TaxonSwap.new(
          user: user,
          change_group: (change_group || "#{self.class.name}-#{id}-children"),
          source: source,
          description: "Automatically generated change from #{FakeView.taxon_change_url( self )}"
        )
        tc.add_input_taxon( child )
        output_child_name = child.name.sub( target_input_taxon.name.strip, output_taxon.name.strip ).strip.gsub( /\s+/, " " )
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
        tc.committer = committer
        tc.commit
      end
    else
      target_input_taxon.children.active.each { |child| child.move_to_child_of( output_taxon ) }
    end
  end

  def index_taxon
    Taxon.elastic_index!( ids: [input_taxa.map(&:id), output_taxa.map(&:id)].flatten.compact )
    true
  end

  def mentioned_users
    return [ ] if description.blank?
    description.mentioned_users
  end

  def new_mentioned_users
    return [ ] unless description && description_changed?
    description.mentioned_users - description_was.to_s.mentioned_users
  end

  def draft?
    committed_on.blank?
  end

end
