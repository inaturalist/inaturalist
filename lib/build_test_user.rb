# frozen_string_literal: true

module BuildTestUser
  TEST_GROUP_NAME = "prod_like_test_users"
  NOTIFIER_LOGIN_PREFIX = "test_user_for_notifications"
  NOTIFIER_POOL_SIZE = 10
  MAX_COUNT = 10_000
  # Use a floor to avoid very old / sparse ID ranges.
  MIN_OBSERVATION_ID = 100_000
  MAX_OBSERVATION_ID = Observation.maximum( :id ).to_i
  MIN_IDENTIFICATION_ID = 100_000
  MAX_IDENTIFICATION_ID = Identification.maximum( :id ).to_i

  Result = Struct.new( :success, :message, :user, :details, keyword_init: true )

  def self.build_user( login:, password:, observations_count:, identifications_for_others_count: )
    update_progress( login, status: "started", progress: 0 )
    now = Time.now
    observations_count = [observations_count.to_i, MAX_COUNT].min
    identifications_for_others_count = [identifications_for_others_count.to_i, MAX_COUNT].min
    # Create a confirmed, test-group user without sending welcome email.
    user = User.new(
      login: login,
      email: "#{login}@inaturalist.org",
      password: password,
      password_confirmation: password,
      test_groups: TEST_GROUP_NAME
    )
    user.skip_welcome_email = true
    user.skip_confirmation_notification! if user.respond_to?( :skip_confirmation_notification! )
    user.confirmed_at = now
    user.confirmation_token = nil
    user.confirmation_sent_at = nil
    user.unconfirmed_email = nil

    unless user.save
      update_progress( login, status: "failed", progress: 100, message: user.errors.full_messages.to_sentence )
      return Result.new(
        success: false,
        message: "Failed to create user: #{user.errors.full_messages.to_sentence}"
      )
    end

    # Pick a random set of other observations.
    observations = randomize_observations( count: observations_count )
    update_progress( login, status: "observations_selected", progress: 10 )

    # For each selected observation, update the user in:
    # - the observation
    # - the identifications associated to this observation, from the original user
    # - the annotations associated to this observation, from the original user
    # - the observation fields associated to this observation, from the original user
    # Extract the list of updated identifications (identifications_from_own_obs)
    identifications_from_own_obs = []
    if observations_count.positive? && observations.any?
      Observation.where( id: observations ).select( :id, :user_id ).find_each do | obs |
        original_user_id = obs.user_id

        identifications_from_this_observation = Identification.
          where( observation_id: obs.id, user_id: original_user_id ).
          pluck( :id )
        if identifications_from_this_observation.any?
          Identification.where( id: identifications_from_this_observation ).
            update_all( user_id: user.id, updated_at: now )
          identifications_from_own_obs.concat( identifications_from_this_observation )
        end

        Annotation.where(
          resource_type: "Observation",
          resource_id: obs.id,
          user_id: original_user_id
        ).update_all( user_id: user.id, updated_at: now )

        ObservationFieldValue.where(
          observation_id: obs.id,
          user_id: original_user_id
        ).update_all( user_id: user.id, updated_at: now )

        Observation.where( id: obs.id ).update_all( user_id: user.id, updated_at: now )
      end
    end
    update_progress( login, status: "observations_assigned", progress: 50 )

    # Pick a random set of other identifications, excluding those already moved.
    indentifications = randomize_identifications( count: identifications_for_others_count,
      exclude_ids: identifications_from_own_obs )
    update_progress( login, status: "identifications_selected", progress: 60 )

    # For each selected identification, update the user
    # Extract the list of associated observations (observations_from_other_ids)
    observations_from_other_ids = []
    if identifications_for_others_count.positive? && indentifications.any?
      Identification.where( id: indentifications ).update_all( user_id: user.id, updated_at: now )
      observations_from_other_ids = Identification.where( id: indentifications ).pluck( :observation_id )
    end
    update_progress( login, status: "identifications_assigned", progress: 75 )

    all_observations = ( observations + observations_from_other_ids ).uniq
    all_identifications = ( identifications_from_own_obs + indentifications ).uniq

    # Reindex changed observation and identification records.
    if all_observations.any?
      Observation.elastic_index!( ids: all_observations, wait_for_index_refresh: true )
      update_progress( login, status: "observations_re_indexed", progress: 85,
        message: "Re-indexed #{all_observations.count} observations" )
    end

    if all_identifications.any?
      Identification.elastic_index!( ids: all_identifications, wait_for_index_refresh: true )
      update_progress( login, status: "identifications_re_indexed", progress: 95,
        message: "Re-indexed #{all_identifications.count} indentifications" )
    end

    # Reindex user and recompute counters for consistent search and stats.
    User.update_observations_counter_cache( user.id )
    User.update_identifications_counter_cache( user.id )
    User.update_annotated_observations_counter_cache( user.id )
    User.update_species_counter_cache( user.id )
    user.reload
    user.elastic_index!
    update_progress( login, status: "user_re_indexed", progress: 100 )

    update_progress( login, status: "complete", progress: 100 )
    Result.new(
      success: true,
      message: [
        "Created user #{user.login}",
        "observations reassigned: #{observations.length}",
        "identifications on those observations reassigned: #{identifications_from_own_obs.length}",
        "other identifications reassigned: #{indentifications.length}"
      ].join( "; " ),
      user: user,
      details: {
        observations: observations,
        identifications_from_own_obs: identifications_from_own_obs,
        indentifications: indentifications,
        observations_from_other_ids: observations_from_other_ids
      }
    )
  end

  def self.apply_updates( target_user_id:, update_action:, count: )
    target_user = User.find_by_id( target_user_id )
    unless target_user&.test_groups_array&.include?( TEST_GROUP_NAME )
      return Result.new( success: false, message: "Please select a valid test user" )
    end

    count = [count.to_i, MAX_COUNT].min
    if count <= 0
      return Result.new( success: false, message: "Please enter a positive number" )
    end

    notifier_users = ensure_notifier_users
    processed = 0
    update_progress( target_user.login, status: "updates_started", progress: 0 )

    case update_action
    when "messages"
      # Create messages from random notifier users.
      count.times do | i |
        notifier_user = notifier_users.sample
        msg = Message.new(
          user: notifier_user,
          from_user: notifier_user,
          to_user: target_user,
          subject: "Test message #{i + 1}",
          body: "Test message generated at #{Time.now.utc}"
        )
        msg.skip_email = true
        msg.save!
        msg.send_message
        processed += 1
      end
      update_progress( target_user.login, status: "messages_created", progress: 100 )
    when "observation_comments"
      obs_ids = Observation.where( user_id: target_user.id ).pluck( :id )
      if obs_ids.empty?
        return Result.new( success: false, message: "User has no observations to comment on" )
      end

      selected_obs_ids = Array.new( count ) { obs_ids.sample }
      obs_by_id = Observation.where( id: selected_obs_ids.uniq ).index_by( &:id )

      # Add comment to the user observations.
      selected_obs_ids.each do | obs_id |
        obs = obs_by_id[obs_id]
        next unless obs

        notifier_user = notifier_users.sample
        Comment.create!(
          parent: obs,
          user: notifier_user,
          body: "Test comment generated at #{Time.now.utc}"
        )
        processed += 1
      end

      update_progress( target_user.login, status: "comments_created", progress: 80 )
      Observation.elastic_index!( ids: selected_obs_ids.uniq, wait_for_index_refresh: true )
      update_progress( target_user.login, status: "elastic_refreshed", progress: 100 )
    when "confirming_identifications", "conflicting_identifications"
      obs_ids = Observation.where( user_id: target_user.id ).pluck( :id )
      if obs_ids.empty?
        return Result.new( success: false, message: "User has no observations to identify" )
      end

      selected_obs_ids = Array.new( count ) { obs_ids.sample }
      obs_by_id = Observation.where( id: selected_obs_ids.uniq ).index_by( &:id )

      # Only consider species and genus active taxa
      active_taxon_ids = Taxon.where(
        is_active: true,
        rank_level: [Taxon::SPECIES_LEVEL, Taxon::GENUS_LEVEL]
      ).pluck( :id )
      if active_taxon_ids.empty?
        return Result.new( success: false, message: "No active taxa available" )
      end

      # Add identifications to the user observations.
      selected_obs_ids.each do | obs_id |
        obs = obs_by_id[obs_id]
        next unless obs

        taxon = nil
        # Confirming identification will use the last identification of the observation
        if update_action == "confirming_identifications"
          last_taxon_id = obs.identifications.order( "id DESC" ).limit( 1 ).pluck( :taxon_id ).first
          taxon = Taxon.find_by_id( last_taxon_id ) if last_taxon_id
          taxon ||= obs.taxon || obs.community_taxon
        # Conflicting identification will use a random taxon
        else
          random_id = active_taxon_ids.sample
          taxon = Taxon.find_by_id( random_id )
        end
        next unless taxon

        notifier_user = notifier_users.sample
        Identification.create!( observation: obs, user: notifier_user, taxon: taxon )
        processed += 1
      end

      update_progress( target_user.login, status: "identifications_created", progress: 80 )
      Observation.elastic_index!( ids: selected_obs_ids.uniq, wait_for_index_refresh: true )
      User.update_species_counter_cache( target_user.id )
      target_user.reload
      target_user.elastic_index!
      update_progress( target_user.login, status: "elastic_refreshed", progress: 100 )
    else
      return Result.new( success: false, message: "Unknown update action" )
    end

    Result.new(
      success: true,
      message: "Created #{processed} #{update_action.humanize.downcase} for #{target_user.login}",
      user: target_user
    )
  end

  def self.randomize_observations( count:, exclude_ids: [] )
    return [] unless count.positive?

    results = []
    attempts = 0
    while results.size < count && attempts < 5
      # Sample IDs and keep only existing rows.
      candidates = Array.new( count ) { rand( MIN_OBSERVATION_ID..MAX_OBSERVATION_ID ) }.uniq
      candidates -= exclude_ids if exclude_ids.present?
      found = Observation.where( id: candidates ).pluck( :id )
      results |= found
      attempts += 1
      puts(
        "BuildTestUser.randomize_observations attempt=#{attempts} " \
          "candidates=#{candidates.size} found=#{found.size} total=#{results.size}"
      )
    end
    results.take( count )
  end

  def self.randomize_identifications( count:, exclude_ids: [] )
    return [] unless count.positive?

    results = []
    attempts = 0
    while results.size < count && attempts < 5
      # Sample IDs and keep only existing rows.
      candidates = Array.new( count ) { rand( MIN_IDENTIFICATION_ID..MAX_IDENTIFICATION_ID ) }.uniq
      candidates -= exclude_ids if exclude_ids.present?
      found = Identification.where( id: candidates ).pluck( :id )
      results |= found
      attempts += 1
      puts(
        "BuildTestUser.randomize_identifications attempt=#{attempts} " \
          "candidates=#{candidates.size} found=#{found.size} total=#{results.size}"
      )
    end
    results.take( count )
  end

  def self.ensure_notifier_users
    users = []
    ( 1..NOTIFIER_POOL_SIZE ).each do | i |
      login = "#{NOTIFIER_LOGIN_PREFIX}_#{i}"
      notifier_user = User.find_by_login( login )
      unless notifier_user
        password = SecureRandom.hex( 16 )
        notifier_user = User.new(
          login: login,
          email: "#{login}@inaturalist.org",
          password: password,
          password_confirmation: password,
          confirmed_at: Time.now
        )
        notifier_user.skip_welcome_email = true
        notifier_user.skip_confirmation_notification! if notifier_user.respond_to?( :skip_confirmation_notification! )
        notifier_user.save!
      end
      notifier_user.user_privileges.
        where( privilege: UserPrivilege::SPEECH ).
        first_or_create
      users << notifier_user
    end
    users
  end

  def self.progress_key( login )
    "build_test_user_progress:#{login}"
  end

  def self.update_progress( login, status:, progress:, message: nil )
    # Cache progress for the admin UI poller.
    puts "BuildTestUser.update_progress login=#{login} status=#{status} progress=#{progress} message=#{message}"
    Rails.cache.write(
      progress_key( login ),
      {
        login: login,
        status: status,
        progress: progress,
        message: message,
        updated_at: Time.now.utc
      },
      expires_in: 2.hours
    )
  end

  def self.progress( login )
    Rails.cache.read( progress_key( login ) )
  end

  private_class_method :ensure_notifier_users
end
