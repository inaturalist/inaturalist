# frozen_string_literal: true

class TaxonChange < ApplicationRecord
  belongs_to :taxon, inverse_of: :taxon_changes
  has_many :taxon_change_taxa, inverse_of: :taxon_change, dependent: :destroy
  has_many :taxa, through: :taxon_change_taxa
  belongs_to :source
  has_many :comments, as: :parent, dependent: :destroy
  has_many :identifications, dependent: :nullify
  belongs_to :user
  belongs_to :committer, class_name: "User"

  has_subscribers to: {
    comments: { notification: "activity" }
  }
  after_create :index_taxon
  after_destroy :index_taxon
  after_update :commit_records_later
  before_validation :sync_status_and_committed_on
  after_save :force_draft_and_reset_votes,
    if: -> { ( status_pending? || status_approved? ) && saved_change_to_taxon_id? }
  after_touch :force_draft_and_reset_votes_if_needed

  validates_presence_of :taxon_id
  validate :uniqueness_of_taxa
  validate :uniqueness_of_output_taxa
  validate :taxa_do_not_include_life
  validate :status_committed_consistency
  validate :approved_requires_threshold
  accepts_nested_attributes_for :source
  accepts_nested_attributes_for :taxon_change_taxa, allow_destroy: true,
    reject_if: ->( attrs ) { attrs["taxon_id"].blank? }

  notifies_users :mentioned_users,
    on: :save,
    delay: false,
    notification: "mention",
    if: lambda( &:prefers_receive_mentions? )

  TAXON_CHANGE_TAXA_JOINS = [
    "LEFT OUTER JOIN taxon_change_taxa tct ON tct.taxon_change_id = taxon_changes.id"
  ].freeze

  TAXON_JOINS = TAXON_CHANGE_TAXA_JOINS + [
    "LEFT OUTER JOIN taxon_change_taxa tct ON tct.taxon_change_id = taxon_changes.id",
    "LEFT OUTER JOIN taxa t1 ON taxon_changes.taxon_id = t1.id",
    "LEFT OUTER JOIN taxa t2 ON tct.taxon_id = t2.id"
  ].freeze

  TYPES = %w(TaxonChange TaxonMerge TaxonSplit TaxonSwap TaxonDrop TaxonStage).freeze

  acts_as_votable
  SUBSCRIBABLE = false
  VOTE_APPROVAL_THRESHOLD = 2

  enum status: {
    draft: "draft",
    committed: "committed",
    withdrawn: "withdrawn",
    pending: "pending",
    approved: "approved"
  }, _prefix: :status

  scope :types, ->( types ) { where( type: types ) }
  scope :committed, -> { where( "committed_on IS NOT NULL" ) }
  scope :uncommitted, -> { where( "committed_on IS NULL" ) }
  scope :change_group, ->( group ) { where( "change_group = ?", group ) }
  scope :iconic_taxon, lambda {| iconic_taxon |
    joins( TAXON_JOINS ).
      where( "t1.iconic_taxon_id = ? OR t2.iconic_taxon_id = ?", iconic_taxon, iconic_taxon )
  }
  scope :source, lambda {| source |
    joins( TAXON_JOINS ).
      where( "t1.source_id = ? OR t2.source_id = ?", source, source )
  }

  scope :ancestor_taxon, lambda {| taxon |
    joins( TAXON_JOINS ).
      where(
        "t1.id = ? OR t2.id = ? OR t1.ancestry = ? OR t1.ancestry = ? OR t1.ancestry LIKE ? OR t1.ancestry LIKE ?",
        taxon, taxon,
        "#{taxon.ancestry}/#{taxon.id}", "#{taxon.ancestry}/#{taxon.id}",
        "#{taxon.ancestry}/#{taxon.id}/%", "#{taxon.ancestry}/#{taxon.id}/%"
      )
  }

  scope :taxon, lambda {| taxon |
    joins( TAXON_JOINS ).
      where( "t1.id = ? OR t2.id = ?", taxon, taxon )
  }

  scope :with_taxon, lambda {| taxon |
    joins( TAXON_CHANGE_TAXA_JOINS ).
      where( "taxon_changes.taxon_id = ? OR tct.taxon_id = ?", taxon, taxon )
  }

  scope :input_taxon, lambda {| taxon |
    joins( TAXON_JOINS ).
      where(
        "( taxon_changes.type IN ( 'TaxonSwap', 'TaxonMerge' ) AND t2.id = ? ) OR " \
          "( taxon_changes.type IN ( 'TaxonSplit', 'TaxonDrop', 'TaxonStage' ) AND taxon_changes.taxon_id = ? )",
        taxon, taxon
      )
  }

  scope :output_taxon, lambda {| taxon |
    joins( TAXON_JOINS ).
      where(
        "( taxon_changes.type IN ( 'TaxonSwap', 'TaxonMerge' ) AND taxon_changes.taxon_id = ? ) OR " \
          "( taxon_changes.type = 'TaxonSplit' AND t2.id = ? )",
        taxon, taxon
      )
  }

  scope :taxon_scheme, lambda {| taxon_scheme |
    joins( TAXON_JOINS ).
      joins(
        "LEFT OUTER JOIN taxon_scheme_taxa tst1 ON tst1.taxon_id = t1.id",
        "LEFT OUTER JOIN taxon_scheme_taxa tst2 ON tst2.taxon_id = t2.id",
        "LEFT OUTER JOIN taxon_schemes ts1 ON ts1.id = tst1.taxon_scheme_id",
        "LEFT OUTER JOIN taxon_schemes ts2 ON ts2.id = tst2.taxon_scheme_id"
      ).
      where( "ts1.id = ? OR ts2.id = ?", taxon_scheme, taxon_scheme )
  }

  scope :by, ->( user ) { where( user_id: user ) }

  def to_s
    "<#{self.class} #{id}>"
  end

  def committed?
    !committed_on.blank?
  end

  def rank_level_conflict?
    return false unless ["TaxonSwap", "TaxonMerge"].include? type

    if type == "TaxonSwap"
      if input_taxa[0].children.where( is_active: true ).map {| c | c.rank_level >= output_taxa[0].rank_level }.any?
        input_taxa_rank_level_conflict = input_taxa[0]
      end
    elsif type == "TaxonMerge"
      out_rank = output_taxa.first&.rank_level
      input_taxa_rank_level_conflict = input_taxa.detect do | input_taxon |
        input_taxon.children.where( is_active: true ).where( "rank_level >= ?", out_rank ).exists?
      end
    end
    return false unless input_taxa_rank_level_conflict

    input_taxa_rank_level_conflict
  end

  def active_children_conflict?
    return false if move_children?

    # inputs can't have active children
    if ["TaxonSwap", "TaxonSplit", "TaxonDrop"].include? type
      return false unless input_taxa.any? {| t | t.children.any?( &:is_active ) }
      return false if is_a?( TaxonSplit ) && is_branching?
    # unless they are also inputs
    elsif type == "TaxonMerge"
      return false unless input_taxa.any? do | t |
        t.children.any? {| e | e.is_active && ( !input_taxa.map( &:id ).include? e.id ) }
      end
    elsif type == "TaxonStage"
      return false
    end
    true
  end

  def automatable_for_output?( output_taxon )
    return true unless is_a?( TaxonSplit ) && is_branching?

    output_taxon_id = output_taxon.is_a?( Taxon ) ? output_taxon.id : output_taxon
    input_taxon.id != output_taxon_id
  end

  def committable_by?( user )
    return false unless user
    return false unless user.is_curator?

    uneditable_input_taxon = input_taxa.detect {| t | !t.protected_attributes_editable_by?( user ) }
    uneditable_output_taxon = nil
    unless uneditable_input_taxon
      uneditable_output_taxon = output_taxa.
        detect {| t | !t.is_active && !t.activated_protected_attributes_editable_by?( user ) }
    end
    uneditable_input_taxon.blank? && uneditable_output_taxon.blank?
  end

  # Override in subclasses that use self.taxon_change_taxa as the input
  def add_input_taxon( taxon )
    self.taxon = taxon
  end

  # Override in subclasses that use self.taxon as the output
  def add_output_taxon( taxon )
    taxon_change_taxa.build( taxon: taxon, taxon_change: self )
  end

  def input_taxa
    [taxon].compact
  end

  def output_taxa
    taxon_change_taxa.reject( &:_destroy ).map( &:taxon ).sort_by( &:id )
  end

  def verb_phrase
    self.class.name.underscore.split( "_" )[1..].join( " " ).downcase
  end

  class PermissionError < StandardError; end
  class ActiveChildrenError < StandardError; end
  class RankLevelError < StandardError; end

  def requires_approval?
    if is_a?( TaxonDrop ) || is_a?( TaxonStage )
      return false
    end

    single_input_taxon = is_a?( TaxonMerge ) ? input_taxa.first : input_taxon
    plant_id = Taxon::ICONIC_TAXA_BY_NAME["Plantae"]&.id
    if single_input_taxon.nil? || single_input_taxon.iconic_taxon_id.nil?
      return false
    end
    if single_input_taxon.iconic_taxon_id == plant_id
      return true
    end

    false
  end

  # Override in subclasses
  def commit
    if CONFIG.content_freeze_enabled
      raise I18n.t( "cannot_be_changed_during_a_content_freeze" )
    end
    unless committable_by?( committer )
      raise PermissionError, "Committing user doesn't have permission to commit"
    end

    if active_children_conflict?
      raise ActiveChildrenError, "Input taxon cannot have active children"
    end
    if rank_level_conflict?
      raise RankLevelError, "Output taxon rank level not coarser than rank level of an input taxon's active children"
    end

    if requires_approval? && status_draft?
      update_attribute( :status, :pending )
      return
    elsif requires_approval? && !status_approved
      raise ApprovalError, "Requires approval"
    end
    unless is_a?( TaxonSplit ) && is_branching?
      input_taxa.each do | t |
        t.update!(
          is_active: false,
          skip_only_inactive_children_if_inactive: move_children? || !active_children_conflict?
        )
      end
    end
    output_taxa.each do | t |
      next if is_a?( TaxonSplit ) && t.id == input_taxon.id && input_taxon.is_active

      t.update!(
        is_active: true,
        skip_only_inactive_children_if_inactive: move_children?,
        skip_taxon_framework_checks: true
      )
    end
    assign_attributes( committed_on: Time.current, status: :committed )
    save( validate: false )
  end

  # For all records with a taxon association affected by this change, update the record if
  # possible / desired by its owner, or generate an update for the owner notifying them of
  # the change
  def commit_records( options = {} )
    # unless draft?
    if CONFIG.content_freeze_enabled
      raise I18n.t( "cannot_be_changed_during_a_content_freeze" )
    end

    unless valid?
      msg = "Failed to commit records for #{self}: #{errors.full_messages.to_sentence}"
      # Rails.logger.error "[ERROR #{Time.now}] #{msg}"
      # return
      raise msg
    end
    if input_taxa.blank?
      # return
      raise "Failed to commit records for #{self}: no input taxa"
    end

    Rails.logger.info "[INFO #{Time.now}] #{self}: starting commit_records"
    notified_user_ids = []
    associations_to_update = %w(identifications observations listed_taxa taxon_links observation_field_values)
    has_many_reflections = associations_to_update.map do | a |
      Taxon.reflections.detect {| k, _v | k.to_s == a }
    end
    has_many_reflections.each do | k, reflection |
      Rails.logger.info "[INFO #{Time.now}] #{self}: committing #{k}"
      try_and_try_again(
        [
          ActiveRecord::RecordNotUnique,
          PG::UniqueViolation,
          NoMethodError
        ], sleep: 1, tries: 10
      ) do
        find_batched_records_of( reflection ) do | batch |
          auto_updatable_records = []
          batch_users_to_notify = []
          if options[:debug]
            Rails.logger.info(
              "[INFO #{Time.now}] #{self}: committing #{k}, batch starting with #{batch[0]}"
            )
          end
          batch.each do | record |
            record_has_user = record.respond_to?( :user ) && record.user
            if !options[:skip_updates] && record_has_user && !notified_user_ids.include?( record.user.id )
              batch_users_to_notify << record.user.id
              notified_user_ids << record.user.id
            end
            next unless automatable? &&
              ( !record_has_user || record.user.prefers_automatic_taxonomic_changes? ) &&
              !( record.is_a?( Identification ) && record.hidden? )

            auto_updatable_records << record
          end
          if options[:debug]
            Rails.logger.info(
              "[INFO #{Time.now}] #{self}: committing #{k}, #{auto_updatable_records.size} automatable records"
            )
          end
          unless auto_updatable_records.blank?
            update_records_of_class( reflection.klass, options.merge( records: auto_updatable_records ) )
          end
          next if batch_users_to_notify.empty?

          action_attrs = {
            resource: self,
            notifier: self,
            notification: "committed"
          }
          action = UpdateAction.first_with_attributes( action_attrs )
          action&.append_subscribers( batch_users_to_notify.uniq )
        end
      end
    end
    update_counts
    ensure_community_taxa_and_identification_categories_set_correctly
    update_counts
    Rails.logger.info "[INFO #{Time.now}] #{self}: finished commit_records"
  end

  def ensure_community_taxa_and_identification_categories_set_correctly
    affected_taxon_ids = [input_taxa, output_taxa].flatten.compact.map( &:id )
    Observation.where( taxon_id: affected_taxon_ids ).
      includes( {
        identifications: [
          :taxon, :moderator_actions, :stored_preferences
        ],
        user: [:stored_preferences]
      } ).
      find_in_batches_in_subsets( batch_size: 100 ) do | batch |
      batch.each do | observation |
        observation.set_community_taxon
        if observation.changed?
          observation.skip_indexing = true
          observation.save!
        end
        Identification.update_categories_for_observation(
          observation,
          skip_reload: true,
          skip_indexing: true
        )
      end
      Observation.elastic_index!( ids: batch.map( &:id ) )
      Identification.elastic_index!(
        ids: Identification.where( observation_id: batch.map( &:id ) ).pluck( :id )
      )
    end
  end

  def update_counts
    [input_taxa, output_taxa].flatten.compact.each do | taxon |
      Rails.logger.info "[INFO #{Time.now}] #{self}: updating counts for #{taxon}"
      Taxon.where( id: taxon.id ).update_all(
        observations_count: Observation.of( taxon ).count,
        listed_taxa_count: ListedTaxon.where( taxon_id: taxon ).count
      )
      taxon.elastic_index!
    end
  end

  def find_batched_records_of( reflection, & )
    input_taxon_ids = input_taxa.to_a.compact.map( &:id )
    return if input_taxon_ids.empty?

    case reflection.klass.to_s
    when "Observation"
      Observation.search_in_batches( ident_taxon_id: input_taxon_ids.join( "," ), & )
    # Omitting using ES for idents now until the ident index gets fully
    # rebuilt. This should be slower but more reliable
    # when "Identification"
    #   page = 1
    #   loop do
    #     results = Identification.elastic_paginate(
    #       filters: [
    #         { terms: { "taxon.ancestor_ids.keyword" => input_taxon_ids } },
    #         { term: { current: true } }
    #       ],
    #       page: page,
    #       per_page: 100
    #     )
    #     break if results.blank?
    #     block.call( results )
    #     page += 1
    #   end
    when "Identification"
      Identification.where( taxon_id: input_taxon_ids, current: true ).
        find_in_batches_in_subsets( & )
    when "ObservationFieldValue"
      ObservationFieldValue.
        joins( :observation_field ).
        where( "value IN (?)", input_taxon_ids.map( &:to_s ) ).
        find_in_batches( & )
    else
      scope = reflection.klass.where( "#{reflection.foreign_key} IN (?)", input_taxon_ids )
      # sometimes reflections have custom scopes that need to be applied
      scope = scope.merge( reflection.scope ) if reflection.scope
      scope.find_in_batches_in_subsets( & )
    end
  end

  # Change all records associated with input taxa to use the selected taxon
  def update_records_of_class( klass, options = {}, & )
    if klass.respond_to?( :update_for_taxon_change )
      klass.update_for_taxon_change( self, options, & )
      return
    end
    records = if options[:records]
      options[:records]
    else
      scope = klass.send( @klass.name.underscore.pluralize ).where( "#{klass.table_name}.taxon_id IN (?)", input_taxa )
      scope = scope.where( "user_id = ?", options[:user] ) if options[:user]
      scope = scope.where( options[:conditions] ) if options[:conditions]
      scope = scope.includes( options[:include] ) if options[:include]
      scope
    end
    proc = proc do | record |
      taxon = options[:taxon] || output_taxon_for_record( record )
      if taxon
        record.update( taxon: taxon )
      end
      yield( record ) if block_given?
    end
    if records.respond_to?( :find_each )
      records.find_each( &proc )
    else
      records.each( &proc )
    end
  end

  def output_taxon_for_record( _record )
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
    if committed_on.nil? && !debug
      raise "Reverting requires committed_on not to be nil"
    end

    logger.info "[INFO #{Time.now}] Destroying identifications..."
    unless debug
      identifications.find_each( &:destroy )
    end
    in_taxon = input_taxa.first if input_taxa.size == 1
    if in_taxon && !output_taxa.blank?
      listed_taxa_sql = <<-SQL
        UPDATE listed_taxa SET taxon_id = #{in_taxon.id} FROM places WHERE
          listed_taxa.taxon_id IN ( #{output_taxa.map( &:id ).join( ',' )} )
          AND ( listed_taxa.updated_at BETWEEN '#{( committed_on + 0.hours ).to_s( :db )}' AND '#{( committed_on + 1.day ).to_s( :db )}')
      SQL
      logger.info "[INFO #{Time.now}] Reverting listed taxa: #{listed_taxa_sql}"
      ActiveRecord::Base.connection.execute( listed_taxa_sql ) unless debug
      taxon_link_sql = <<-SQL
        UPDATE taxon_links SET taxon_id = #{in_taxon.id} FROM places WHERE
          taxon_links.taxon_id IN ( #{output_taxa.map( &:id ).join( ',' )} )
          AND ( taxon_links.updated_at BETWEEN '#{( committed_on + 0.hours ).to_s( :db )}' AND '#{( committed_on + 1.day ).to_s( :db )}')
      SQL
      logger.info "[INFO #{Time.now}] Reverting taxon links: #{taxon_link_sql}"
      ActiveRecord::Base.connection.execute( taxon_link_sql ) unless debug
    end
    input_taxa.each do | input_taxon |
      input_taxon.update( is_active: true ) unless debug
    end
    if options[:deactivate_output_taxa]
      output_taxa.each do | output_taxon |
        next if debug || input_taxa.include?( output_taxon )

        output_taxon.update( is_active: false )
      end
    end
    # output taxa may or may not need to be made inactive, impossible to say in code
    logger.info "[INFO #{Time.now}] Finished partial revert for #{self}"
  end

  def automatable?
    output_taxa.size == 1
  end

  def taxon_change_commit_records_unique_hash
    { "TaxonSwap::commit_records": id }
  end

  def commit_records_later
    return true unless saved_change_to_committed_on? && committed?

    delay( priority: USER_INTEGRITY_PRIORITY,
      unique_hash: taxon_change_commit_records_unique_hash ).
      commit_records
    true
  end

  def commit_records_job
    Delayed::Job.where( unique_hash: taxon_change_commit_records_unique_hash.to_s ).first
  end

  def editable_by?( user )
    return false if user.blank?

    return true if user.is_curator?

    return true if user.id == user_id

    false
  end

  def uniqueness_of_taxa
    return true if type == "TaxonSplit"

    taxon_ids = [taxon_id, taxon_change_taxa.map( &:taxon_id )].flatten.compact
    return unless taxon_ids.size != taxon_ids.uniq.size

    errors.add( :base, "input and output taxa must be unique" )
  end

  def uniqueness_of_output_taxa
    return true unless type == "TaxonSplit"

    taxon_ids = taxon_change_taxa.map( &:taxon_id )
    return unless taxon_ids.size != taxon_ids.uniq.size

    errors.add( :base, "output taxa must be unique" )
  end

  def taxa_do_not_include_life
    return unless Taxon::LIFE

    taxon_ids_involved = [taxon_id, taxon_change_taxa.map( &:taxon_id )].flatten.compact
    return unless taxon_ids_involved.include?( Taxon::LIFE.id )

    errors.add( :base, :life_taxon_cannot_be_involved )
  end

  def move_input_children_to_output( target_input_taxon )
    return unless move_children?

    unless target_input_taxon.is_a?( Taxon )
      target_input_taxon = Taxon.find_by_id( target_input_taxon )
    end
    move_child = proc do | child |
      child.skip_locks = true
      child.skip_taxon_framework_checks = true
      output_taxon.skip_locks = true
      output_taxon.skip_taxon_framework_checks = true
      child.move_to_child_of( output_taxon )
    end
    if target_input_taxon.rank_level &&
        target_input_taxon.rank_level <= Taxon::GENUS_LEVEL &&
        output_taxon.rank == target_input_taxon.rank &&
        (
          target_input_taxon.genus.blank? || output_taxon.genus.blank? ||
          output_taxon.genus.try( :name ) != target_input_taxon.genus.try( :name )
        )
      target_input_taxon.children.active.each do | child |
        # If for some horrible reason people are swapping replacing taxa with
        # their own children, at least don't get into some kind of invite
        # change loop.
        if input_taxa.include?( child ) || output_taxa.include?( child )
          next
        end

        tc = TaxonSwap.new(
          user: user,
          change_group: change_group || "#{self.class.name}-#{id}-children",
          source: source,
          description: "Automatically generated change from #{UrlHelper.taxon_change_url( self )}",
          move_children: true
        )
        tc.add_input_taxon( child )
        output_child_name = if child.rank_level < Taxon::SPECIES_LEVEL
          child.name.sub( child.species_name.to_s.strip, output_taxon.species_name.to_s.strip ).strip.gsub( /\s+/, " " )
        elsif child.species?
          child.name.sub( child.genus_name.to_s.strip, output_taxon.genus_name.to_s.strip ).strip.gsub( /\s+/, " " )
        else
          child.name
        end
        output_child = output_taxon.children.detect {| c | c.name == output_child_name }
        if output_child
          # puts "found existing output_child: #{output_child}"
        else
          output_child = Taxon.new(
            name: output_child_name,
            rank: child.rank,
            is_active: false,
            skip_locks: true
          )
          output_child.save!
          output_child.update( parent: output_taxon, skip_locks: true )
        end
        tc.add_output_taxon( output_child )
        tc.save!
        tc.committer = committer
        tc.commit
      end
    else
      target_input_taxon.children.active.each( &move_child )
    end
  end

  def index_taxon
    # unless draft?
    Taxon.elastic_index!( ids: [input_taxa.map( &:id ), output_taxa.map( &:id )].flatten.compact )
    true
  end

  def mentioned_users
    return [] if description.blank?

    description.mentioned_users
  end

  def draft?
    committed_on.blank?
  end

  def votable_callback
    up = votes_for.where( vote_flag: true, vote_scope: nil ).count
    threshold = VOTE_APPROVAL_THRESHOLD
    if status_pending? && up >= threshold
      update_columns( status: "approved", updated_at: Time.current )
    elsif status_approved? && up < threshold
      update_columns( status: "pending",  updated_at: Time.current )
    end
  end

  def unvote_by( ... )
    result = super
    votable_callback

    result
  end

  def approved_requires_threshold
    return unless status_approved?

    up = votes_for.where( vote_flag: true, vote_scope: nil ).count
    return unless up < VOTE_APPROVAL_THRESHOLD

    errors.add( :status, "cannot be approved without #{VOTE_APPROVAL_THRESHOLD} curator votes" )
  end

  private

  def sync_status_and_committed_on
    if committed_on.present?
      self.status = "committed"
    elsif !committed_on.present? && status == "committed"
      self.status = "draft"
    end
  end

  def status_committed_consistency
    if committed_on.present? && status != "committed"
      errors.add( :status, "must be 'committed' when committed_on is set" )
    end
    return unless status == "committed" && committed_on.blank?

    errors.add( :committed_on, "must be present when status is 'committed'" )
  end

  def force_draft_and_reset_votes_if_needed
    return unless status_pending? || status_approved?

    force_draft_and_reset_votes
  end

  def force_draft_and_reset_votes
    ActsAsVotable::Vote.where( votable: self ).delete_all
    updates = { status: "draft", updated_at: Time.current }
    update_columns( updates )
  end
end
