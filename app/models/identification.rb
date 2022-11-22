#encoding: utf-8
class Identification < ApplicationRecord
  include ActsAsElasticModel
  acts_as_spammable fields: [ :body ],
                    comment_type: "comment",
                    automated: false

  blockable_by lambda {|identification| identification.observation.try(:user_id) }
  has_moderator_actions %w(hide unhide)
  belongs_to_with_uuid :observation
  belongs_to :user
  belongs_to_with_uuid :taxon
  belongs_to :taxon_change
  belongs_to :previous_observation_taxon, class_name: "Taxon"
  has_many :project_observations, :foreign_key => :curator_identification_id, :dependent => :nullify
  validates_presence_of :observation, :user
  validates_presence_of :taxon, 
                        :message => "for an ID must be something we recognize"
  validates_length_of :body, within: 0..Comment::MAX_LENGTH, on: :create, allow_blank: true
  
  before_create :replace_inactive_taxon

  # Note: order is important here. set_previous_observation_taxon should
  # happen before update_other_identifications
  before_save :set_previous_observation_taxon,
              :update_other_identifications
              
  before_create :set_disagreement
  after_create :update_observation_if_test_env,
               :create_observation_review,
               :update_curator_identification,
               :update_quality_metrics
  after_update :update_curator_identification,
               :update_quality_metrics

  # Note: update_categories must run last, or at least after update_observation,
  # b/c it relies on the community taxon being up to date
  after_commit :update_categories,
               :update_obs_stats,
               :update_observation,
               :update_user_counter_cache,
               unless: Proc.new { |i| i.observation.destroyed? }
  
  # Rails 3.x runs after_commit callbacks in reverse order from after_destroy.
  # Yes, really. set_last_identification_as_current needs to run after_commit
  # because of the unique index constraint on current, which will complain if
  # you try to set the last ID as current when this one hasn't really been
  # deleted yet, i.e. before the transaction is complete.
  after_commit :update_obs_stats_after_destroy,
                 :update_observation_after_destroy,
                 :revisit_curator_identification, 
                 :set_last_identification_as_current,
                 :remove_automated_observation_reviews,
               :on => :destroy,
               unless: Proc.new { |i| i.observation.destroyed? }
  
  include Shared::TouchesObservationModule
  include ActsAsUUIDable

  acts_as_votable
  SUBSCRIBABLE = false

  attr_accessor :skip_observation
  attr_accessor :html
  attr_accessor :captive_flag
  attr_accessor :skip_set_previous_observation_taxon
  attr_accessor :skip_set_disagreement
  attr_accessor :bulk_delete
  attr_accessor :wait_for_obs_index_refresh

  preference :vision, :boolean, default: false

  %w(improving supporting leading maverick).each do |category|
    const_set category.upcase, category
    define_method "#{category}?" do
      self.category == category
    end
  end

  CATEGORIES = [
    IMPROVING,
    SUPPORTING,
    LEADING,
    MAVERICK
  ]
  
  notifies_subscribers_of :observation, :notification => "activity", :include_owner => true, 
    :queue_if => lambda {|ident| 
      ident.taxon_change_id.blank?
    },
    :if => lambda {|notifier, subscribable, subscription|
      return true unless notifier && subscribable && subscription
      return true if subscription.user && subscription.user.prefers_redundant_identification_notifications
      subscribers_identification = subscribable.identifications.current.detect{|i| i.user_id == subscription.user_id}
      return true unless subscribers_identification
      return true unless notifier.body.blank?
      subscribers_identification.taxon_id != notifier.taxon_id
    }
  auto_subscribes :user, :to => :observation, :if => lambda {|ident, observation| 
    ident.user_id != observation.user_id
  }
  notifies_users :mentioned_users,
    on: :save,
    delay: false,
    notification: "mention",
    if: lambda {|u| u.prefers_receive_mentions? }

  earns_privilege UserPrivilege::SPEECH
  earns_privilege UserPrivilege::COORDINATE_ACCESS
  
  scope :for, lambda {|user|
    joins(:observation).where("observation.user_id = ?", user)
  }
  scope :for_others, -> { joins(:observation).where( "observations.user_id != identifications.user_id" ) }
  scope :by, lambda {|user| where("identifications.user_id = ?", user)}
  scope :not_by, lambda {|user| where("identifications.user_id != ?", user)}
  scope :of, lambda { |taxon|
    taxon = Taxon.find_by_id(taxon.to_i) unless taxon.is_a? Taxon
    return where("1 = 2") unless taxon
    c = taxon.descendant_conditions.to_sql
    c[0] = "taxa.id = #{taxon.id} OR #{c[0]}"
    joins(:taxon).where(c)
  }
  scope :on, lambda {|date| where(Identification.conditions_for_date("identifications.created_at", date)) }
  scope :current, -> { where(:current => true) }
  scope :outdated, -> { where(:current => false) }
  
  def to_s
    "<Identification #{id} observation_id: #{observation_id} taxon_id: #{taxon_id} user_id: #{user_id} current: #{current?}>"
  end

  def to_plain_s(options = {})
    "Identification #{id} by #{user.login}"
  end

  # Validations ###############################################################

  def uniqueness_of_current
    return true unless observation && user_id
    return true unless current?
    current_ident = observation.identifications.by(user_id).current.last
    if current_ident && current_ident.id != id && current_ident.created_at > created_at
      errors.add(:current, "can't be set when a newer current identification exists for this user")
    end
    true
  end
  
  # Callbacks ###############################################################

  def replace_inactive_taxon
    return true if taxon && taxon.is_active?
    return true unless candidate = taxon.current_synonymous_taxon
    self.taxon = candidate
    true
  end

  def update_other_identifications
    return true unless ( will_save_change_to_current? || new_record? ) && current?
    scope = if id
      Identification.where("observation_id = ? AND user_id = ? AND id != ?", observation_id, user_id, id)
    else
      Identification.where("observation_id = ? AND user_id = ?", observation_id, user_id)
    end
    scope.update_all( current: false )
    true
  end

  def set_previous_observation_taxon
    return true if skip_set_previous_observation_taxon
    return true unless previous_observation_taxon.blank?
    self.previous_observation_taxon_id = if new_record?
      observation.probable_taxon( force: true ).try(:id)
    elsif previous_probable_taxon = observation.probable_taxon( force: true, before: id )
      if observation.prefers_community_taxon == false || !observation.user.prefers_community_taxa?
        previous_probable_taxon.id
      else
        observation.taxon.try(:id)
      end
    end
    unless previous_observation_taxon_id
      working_created_at = created_at || Time.now
      previous_ident = observation.identifications.select do |i|
        i.persisted? && i.current && i.created_at < working_created_at && i.user_id == user_id
      end.last
      previous_ident ||= observation.identifications.select do |i|
        i.persisted? && i.created_at < working_created_at && i.user_id == user_id
      end.last
      self.previous_observation_taxon_id = previous_ident.try(:taxon_id) || observation.taxon_id
    end
    true
  end

  def set_disagreement( options = {} )
    return true if skip_set_disagreement

    # Can't disagree with nothing or roots
    if !previous_observation_taxon || !previous_observation_taxon.grafted?
      self.disagreement = nil
      return true
    end

    # Can't disagree if no current identifications
    if observation.identifications.current.empty?
      self.disagreement = nil
      return true
    end

    # Can't disagree when suggesting an ungrafted taxon
    if !taxon.grafted? && !taxon.children.exists?
      self.disagreement = nil
      return true
    end

    # Explicit disagreement can only happen when suggesting a taxon that is an
    # ancestor of the previous taxon
    if disagreement? && previous_observation_taxon.ancestor_ids.include?( taxon.id )
      return true
    end

    # Implicit disagreement
    ancestor_of_previous_observation_taxon = previous_observation_taxon.self_and_ancestor_ids.include?( taxon_id )
    descendant_of_previous_observation_taxon = taxon.self_and_ancestor_ids.include?( previous_observation_taxon.id )
    self.disagreement = !ancestor_of_previous_observation_taxon && !descendant_of_previous_observation_taxon

    true
  end

  def update_observation_if_test_env
    # this model uses an after_commit callback for method update_observation to keep
    # the obs ES index in sync. But in the test env when running specs there are no
    # commits with the transactional db cleaning strategy. Use this method to run
    # update_observation for specs
    update_observation if Rails.env.test?
  end

  # Update the observation
  def update_observation
    return true unless observation
    return true if skip_observation
    return true if destroyed?
    attrs = {}
    if user_id == observation.user_id || !observation.community_taxon_rejected?
      observation.skip_identifications = true
      attrs = {}
      if user_id == observation.user_id
        species_guess = observation.species_guess
        unless taxon.taxon_names.exists?(name: species_guess)
          species_guess = taxon.common_name.try(:name) || taxon.name
        end
        attrs[:species_guess] = species_guess
      end
      ProjectUser.delay(priority: INTEGRITY_PRIORITY,
        unique_hash: { "ProjectUser::update_taxa_obs_and_observed_taxa_count_after_update_observation": [
          observation.id, observation.user_id ] }
      ).update_taxa_obs_and_observed_taxa_count_after_update_observation(observation.id, observation.user_id)
    end
    observation.wait_for_index_refresh ||= !!wait_for_obs_index_refresh
    observation.identifications.reload
    observation.set_community_taxon(force: true)
    observation.set_taxon_geoprivacy
    observation.skip_identification_indexing = true
    observation.skip_indexing = true
    observation.update(attrs)
    true
  end
  
  def update_observation_after_destroy
    return true unless self.observation
    # return true unless self.observation.user_id == self.user_id
    return true if skip_observation

    if last_current = observation.identifications.current.by(user_id).order("id ASC").last
      last_current.update_observation
      return true
    end
    
    attrs = {}
    if user_id == observation.user_id
      # update the species_guess
      species_guess = observation.species_guess
      if !taxon.blank? && !taxon.taxon_names.exists?(:name => species_guess)
        species_guess = nil
      end
      attrs = {:species_guess => species_guess, :taxon => nil, :iconic_taxon_id => nil}
      ProjectUser.delay(priority: INTEGRITY_PRIORITY,
        unique_hash: { "ProjectUser::update_taxa_obs_and_observed_taxa_count_after_update_observation": [
          observation.id, self.user_id ] }
      ).update_taxa_obs_and_observed_taxa_count_after_update_observation(observation.id, self.user_id)
    end
    observation.skip_identifications = true
    observation.identifications.reload
    observation.set_community_taxon
    attrs[:community_taxon] = observation.community_taxon
    observation.update(attrs)
    true
  end
  
  #
  # Update the identification stats in the observation.
  #
  def update_obs_stats
    return true unless observation
    return true if skip_observation || bulk_delete
    observation.update_stats(:include => self)
    true
  end

  def update_obs_stats_after_destroy
    update_obs_stats
  end
  
  # Set the project_observation curator_identification_id if the
  # identifier is a curator of a project that the observation is submitted to
  def update_curator_identification
    return true if self.observation.blank?
    Identification.
      delay(
        priority: INTEGRITY_PRIORITY,
        unique_hash: { "Identification::run_update_curator_identification": id },
        run_at: 1.minute.from_now
      ).
      run_update_curator_identification( id )
    true
  end
  
  # Update the counter cache in users.  That cache ONLY tracks observations 
  # made for others.
  def update_user_counter_cache
    return true unless self.user && self.observation
    return true if user.destroyed?
    return true if bulk_delete
    if self.user_id != self.observation.user_id
      User.delay(
        unique_hash: { "User::update_identifications_counter_cache": user_id },
        run_at: 5.minutes.from_now
      ).update_identifications_counter_cache(user_id)
    end
    true
  end

  def set_last_identification_as_current
    last_current = observation.identifications.current.by( user_id ).order( "id ASC" ).last
    return true if last_current
    last_outdated = observation.identifications.outdated.by( user_id ).order( "id ASC" ).last
    if last_outdated
      begin
        Identification.where( id: last_outdated ).update_all( current: true )
        Identification.elastic_index!( ids: [last_outdated] )
      rescue PG::Error, ActiveRecord::RecordNotUnique => e
        raise e unless e.message =~ /index_identifications_on_current/
        # assume that if the unique key constraint complained, then there's already a current ident
      end
    end
    true
  end
  
  # Revise the project_observation curator_identification_id if the
  # a curator's identification is deleted to be nil or that of another curator
  def revisit_curator_identification
    Identification.delay(
      priority: INTEGRITY_PRIORITY,
      unique_hash: {
        "Identification::revisit_curator_identification": [ observation_id, user_id ]
      }
    ).run_revisit_curator_identification( self.observation_id, self.user_id )
    true
  end

  def create_observation_review
    return true if skip_observation || bulk_delete
    ObservationReview.where(observation_id: observation_id, user_id: user_id).
      first_or_create.
      update( reviewed: true, updated_at: Time.now )
    true
  end

  def remove_automated_observation_reviews
    ObservationReview.where(observation_id: observation_id,
      user_id: user_id, user_added: false).destroy_all
    true
  end

  def flagged_with(flag, options)
    evaluate_new_flag_for_spam(flag)
    elastic_index!
    if observation
      observation.elastic_index!
    end
  end

  # /Callbacks ##############################################################
  
  #
  # Tests whether this identification should be considered an agreement with
  # the observation's taxon.  If this identification has the same taxon
  # or a descendant taxon of the observation's taxon, then they agree.
  #
  def is_agreement?(options = {})
    return false if frozen?
    o = options[:observation] || observation
    return false if o.taxon_id.blank?
    return false if o.user_id == user_id
    return false if o.community_taxon_id.blank?
    return true if taxon_id == o.taxon_id
    taxon.in_taxon? o.taxon_id
  end
  
  # def old_is_disagreement?(options = {})
  #   return false if frozen?
  #   o = options[:observation] || observation
  #   return false if o.user_id == user_id
  #   return false if o.identifications.count == 1
  #   prior_community_taxon = o.get_community_taxon( before: id, force: true )
  #   !prior_community_taxon.self_and_ancestor_ids.include?( taxon.id ) && !taxon.self_and_ancestor_ids.include?( prior_community_taxon.id )
  # end

  def is_disagreement?( options = {} )
    disagreement
  end
  
  #
  # Tests whether this identification should be considered an agreement with
  # another identification.
  #
  def in_agreement_with?(identification)
    return false unless identification
    return false if identification.taxon_id.nil?
    return true if self.taxon_id == identification.taxon_id
    self.taxon.in_taxon? identification.taxon
  end

  def update_quality_metrics
    if captive_flag == "1"
      QualityMetric.vote(user, observation, QualityMetric::WILD, false)
    end
    true
  end

  def self.update_categories_for_observation( o, options = {} )
    unless options[:skip_reload]
      o = Observation.where( id: o ).includes(:community_taxon).first
    end
    return unless o
    if options[:skip_reload]
      idents = o.identifications
    else
      idents = Identification.
        includes(:taxon).
        where( observation_id: o.id )
    end
    categories = {
      improving: [],
      leading: [],
      supporting: [],
      maverick: [],
      removed: []
    }
    idents.sort_by(&:id).each do |ident|
      ancestor_of_community_taxon = o.community_taxon && o.community_taxon.ancestor_ids.include?( ident.taxon_id )
      descendant_of_community_taxon = o.community_taxon && ident.taxon.ancestor_ids.include?( o.community_taxon_id )
      matches_community_taxon = o.community_taxon && ( ident.taxon_id == o.community_taxon_id )
      progressive = ( categories[:improving] + categories[:supporting] ).flatten.detect { |i|
        i.taxon.self_and_ancestor_ids.include?( ident.taxon_id )
      }.blank?
      if o.community_taxon.blank? || descendant_of_community_taxon
        categories[:leading] << ident
      elsif ( ancestor_of_community_taxon || matches_community_taxon ) && progressive
        categories[:improving] << ident
      elsif !ancestor_of_community_taxon && !descendant_of_community_taxon && !matches_community_taxon
        categories[:maverick] << ident
      else
        categories[:supporting] << ident
      end
    end
    categories.each do |category, idents|
      next if idents.compact.blank?
      Identification.where( id: idents.map(&:id) ).update_all( category: category )
    end
    unless options[:skip_indexing]
      Identification.elastic_index!( ids: idents.map(&:id) )
      o.reload
      o.wait_for_index_refresh ||= !!options[:wait_for_obs_index_refresh]
      o.elastic_index!
    end
  end

  def update_categories
    return true if bulk_delete
    if skip_observation
      Identification.delay( run_at: 5.seconds.from_now ).
        update_categories_for_observation( observation_id )
    else
      # update_categories_for_observation will reindex all the observation's
      # identifications, so we both do not need to re-index this individual
      # identification after that happens, and in fact that may result in
      # indexing stale data, e.g. a blank category
      self.skip_indexing = true
      Identification.update_categories_for_observation( observation, {
        wait_for_obs_index_refresh: wait_for_obs_index_refresh
      } )
    end
    true
  end

  def mentioned_users
    return [ ] unless body
    body.mentioned_users
  end

  def vision
    prefers_vision?
  end

  def vision=( val )
    self.preferred_vision = val.yesish?
  end

  def taxon_name
    taxon.try(:name)
  end

  def taxon_rank
    taxon.try(:rank)
  end

  # Static ##################################################################
  
  def self.run_update_curator_identification(ident)
    ident = Identification.find_by_id(ident) unless ident.is_a?(Identification)
    return unless ident
    obs = ident.observation
    return unless obs
    current_ident = if ident.current?
      ident
    else
      obs.identifications.by(ident.user_id).current.order("id asc").last
    end
    return if current_ident.blank?
    obs.project_observations.each do |po|
      if current_ident.user.project_users.exists?(["project_id = ? AND role IN (?)", po.project_id, [ProjectUser::MANAGER, ProjectUser::CURATOR]])
        po.update(:curator_identification_id => current_ident.id)
        ProjectUser.delay(priority: INTEGRITY_PRIORITY,
          unique_hash: { "ProjectUser::update_observations_counter_cache_from_project_and_user":
            [ po.project_id, obs.user_id ] }
        ).update_observations_counter_cache_from_project_and_user(po.project_id, obs.user_id)
        ProjectUser.delay(priority: INTEGRITY_PRIORITY,
          unique_hash: { "ProjectUser::update_taxa_counter_cache_from_project_and_user":
            [ po.project_id, obs.user_id ] }
        ).update_taxa_counter_cache_from_project_and_user(po.project_id, obs.user_id)
        Project.delay(priority: INTEGRITY_PRIORITY,
          unique_hash: { "Project::update_observed_taxa_count": po.project_id }
        ).update_observed_taxa_count(po.project_id)
      end
    end
    obs.reload
    obs.elastic_index!
  end
  
  def self.run_revisit_curator_identification(observation_id, user_id)
    return unless obs = Observation.find_by_id(observation_id)
    return unless usr = User.find_by_id(user_id)
    obs.project_observations.each do |po|
      other_curator_conditions = ["project_id = ? AND role IN (?)", po.project_id, [ProjectUser::MANAGER, ProjectUser::CURATOR]]
      # The ident that was deleted is owned by user who is a curator of a project that that obs belongs to
      if usr.project_users.exists?(other_curator_conditions)
        other_curator_ident = nil

        # that project observation has other identifications that belong to users who are curators use those
        po.observation.identifications.current.each do |other_ident|
          if other_curator_ident = other_ident.user.project_users.exists?(other_curator_conditions)
            po.update(:curator_identification_id => other_ident.id)
            break
          end
        end

        po.update(:curator_identification_id => nil) unless other_curator_ident
        ProjectUser.delay(priority: INTEGRITY_PRIORITY,
          unique_hash: { "ProjectUser::update_observations_counter_cache_from_project_and_user":
            [ po.project_id, obs.user_id ] }
        ).update_observations_counter_cache_from_project_and_user(po.project_id, obs.user_id)
        ProjectUser.delay(priority: INTEGRITY_PRIORITY,
          unique_hash: { "ProjectUser::update_taxa_counter_cache_from_project_and_user":
            [ po.project_id, obs.user_id ] }
        ).update_taxa_counter_cache_from_project_and_user(po.project_id, obs.user_id)
        Project.delay(priority: INTEGRITY_PRIORITY,
          unique_hash: { "Project::update_observed_taxa_count": po.project_id }
        ).update_observed_taxa_count(po.project_id)
      end
    end
    obs.reload
    obs.elastic_index!
  end

  def self.update_for_taxon_change( taxon_change, options = {} )
    input_taxon_ids = taxon_change.input_taxa.map(&:id)
    scope = Identification.current.where( "identifications.taxon_id IN (?)", input_taxon_ids )
    scope = scope.where( user_id: options[:user] ) if options[:user]
    scope = scope.where( "identifications.id IN (?)", options[:records] ) unless options[:records].blank?
    scope = scope.where( options[:conditions] ) if options[:conditions]
    scope = scope.includes( options[:include] ) if options[:include]
    # these are involved in validations, so it helps to load them
    scope = scope.includes( { observation: :observations_places }, :user )
    scope = scope.where( "identifications.created_at < ?", Time.now )
    observation_ids = []
    ident_ids = []
    scope.find_each do |ident|
      next unless output_taxon = taxon_change.output_taxon_for_record( ident )
      next unless taxon_change.automatable_for_output?( output_taxon.id )
      new_ident = Identification.new(
        observation_id: ident.observation_id,
        taxon: output_taxon, 
        user_id: ident.user_id,
        taxon_change: taxon_change,
        disagreement: false,
        skip_set_disagreement: true,
        skip_indexing: true
      )
      if ident.disagreement && ident.previous_observation_taxon && ( current_synonym = ident.previous_observation_taxon.current_synonymous_taxon )
        new_ident.disagreement = true
        new_ident.skip_set_previous_observation_taxon = true
        new_ident.previous_observation_taxon = current_synonym
      end
      new_ident.skip_observation = true
      new_ident.save
      observation_ids << ident.observation_id
      ident_ids << ident.id
      yield( new_ident ) if block_given?
    end
    Identification.current.where( "disagreement AND previous_observation_taxon_id IN (?)", input_taxon_ids ).find_each do |ident|
      ident.skip_observation = true
      if taxon_change.is_a?( TaxonMerge ) || taxon_change.is_a?( TaxonSwap )
        ident.update(
          skip_set_previous_observation_taxon: true,
          previous_observation_taxon: taxon_change.output_taxon,
          skip_indexing: true
        )
        observation_ids << ident.observation_id
      elsif taxon_change.is_a?( TaxonSplit )
        ident.update( disagreement: false, skip_indexing: true )
        observation_ids << ident.observation_id
      end
      ident_ids << ident.id
    end
    observation_ids.uniq.compact.sort.in_groups_of( 100 ) do |obs_ids|
      obs_ids.compact!
      batch = Observation.where( id: obs_ids )
      Observation.preload_associations( batch, [{ identifications: :taxon }, :community_taxon] )
      batch.each do |obs|
        ProjectUser.delay(
          priority: INTEGRITY_PRIORITY,
          unique_hash: {
            "ProjectUser::update_taxa_obs_and_observed_taxa_count_after_update_observation": [ obs.id, obs.user_id ]
          }
        ).update_taxa_obs_and_observed_taxa_count_after_update_observation( obs.id, obs.user_id )
        obs.set_community_taxon( force: true )
        obs.skip_indexing = true
        obs.skip_refresh_check_lists = true
        obs.skip_identifications = true
        obs.save
        Identification.update_categories_for_observation( obs, skip_reload: true, skip_indexing: true )
        ident_ids += obs.identification_ids
      end
    end
    # Get observations that may have received new identifications from this
    # change from a previous attempt to commit records for this change, in case
    # a previous attempt hit an error and stopped before indexing some records
    observation_ids += Identification.connection.execute(
      "SELECT DISTINCT observation_id FROM identifications WHERE taxon_change_id = #{taxon_change.id}"
    ).map {|r| r["observation_id"].to_i }
    observation_ids.uniq!
    ident_ids.uniq!
    
    Identification.elastic_index!( ids: ident_ids )
    Observation.elastic_index!( ids: observation_ids )
  end

  def self.update_disagreement_identifications_for_taxon( taxon )
    return unless taxon = Taxon.find_by_id( taxon ) unless taxon.is_a?( Taxon )
    block = Proc.new{ |ident|
      if ident.taxon.self_and_ancestor_ids.include?( ident.previous_observation_taxon_id )
        ident.update( disagreement: false )
      end
    }
    batch_size = 200
    batch_start_id = 0
    results_remaining = true
    while results_remaining
      begin
        ident_response = Identification.elastic_search(
          size: batch_size,
          filters: [
            { term: { "taxon.ancestor_ids.keyword": taxon.id } },
            { term: { disagreement: true } },
            { range: { id: { gt: batch_start_id } } }
          ],
          sort: { id: :asc },
          source: [:id]
        )
        if !ident_response.response || ident_response.response.hits.total.value < batch_size
          results_remaining = false
        end
        ids = ident_response.response.hits.hits.map{ |h| h._source.id }
        Identification.
          where( id: ids ).
          includes( :taxon ).
          find_each( &block )
        batch_start_id = ids.last
      rescue
        results_remaining = false
      end
    end
  end

  def self.reindex_for_taxon( taxon_id )
    ident_ids = []
    last_id = 0
    while true
      r = Identification.elastic_search(
        source: {
          includes: ["id"],
        },
        filters: [
          { range: { id: { gt: last_id } } },
          { terms: { "taxon.ancestor_ids.keyword" => [taxon_id] } }
        ],
        track_total_hits: true,
        sort: { id: :asc }
      ).per_page( 1000 )
      break unless r.response && r.response.hits && r.response.hits.hits
      new_ident_ids = r.response.hits.hits.map(&:_id)
      break if new_ident_ids.blank?
      last_id = new_ident_ids.last
      ident_ids += new_ident_ids
    end
    Identification.elastic_index!( ids: ident_ids )
  end

  def self.merge_future_duplicates( reject, keeper )
    Rails.logger.debug "[DEBUG] Identification.merge_future_duplicates, reject: #{reject}, keeper: #{keeper}"
    unless reject.is_a?( keeper.class )
      raise "reject and keeper must by of the same class"
    end
    unless reject.is_a?( User )
      raise "Identification.merge_future_duplicates only works for observations right now"
    end
    k, reflection = reflections.detect{|k,r| r.klass == reject.class && r.macro == :belongs_to }
    sql = <<-SQL
      SELECT
        observation_id,
        array_agg(id) AS ids
      FROM
        identifications
      WHERE
        current
        AND #{reflection.foreign_key} IN (#{reject.id},#{keeper.id})
      GROUP BY
        observation_id
      HAVING
        count(*) > 1
    SQL
    connection.execute( sql.gsub(/\s+/, " " ).strip ).each do |row|
      to_merge_ids = row['ids'].to_s.gsub(/[\{\}]/, '').split(',').sort
      idents = Identification.where( id: to_merge_ids )
      if reject_ident = idents.detect{|i| i.send(reflection.foreign_key) == reject.id }
        reject_ident.update( current: false )
      end
    end
  end

end
