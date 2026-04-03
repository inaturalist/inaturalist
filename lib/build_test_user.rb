# frozen_string_literal: true

module BuildTestUser
  TEST_GROUP_NAME = "prod_like_test_users"
  NOTIFIER_LOGIN_PREFIX = "test_user_for_notifications"
  NOTIFIER_POOL_SIZE = 10
  MAX_COUNT = 10_000
  RANDOM_SAMPLE_THRESHOLD = 1_000_000
  # Use a floor to avoid very old / sparse ID ranges.
  MIN_OBSERVATION_ID = 100_000
  MAX_OBSERVATION_ID = Observation.maximum( :id ).to_i
  MIN_IDENTIFICATION_ID = 100_000
  MAX_IDENTIFICATION_ID = Identification.maximum( :id ).to_i

  Result = Struct.new( :success, :message, :user, :details, keyword_init: true )

  def self.enabled?
    CONFIG.build_test_user_enabled == true
  end

  def self.build_user( *args, login: nil, password: nil, observations_count: nil,
                       identifications_for_others_count: nil )
    if args.length == 1 && args.first.is_a?( Hash )
      payload = args.first
      login = payload[:login]
      password = payload[:password]
      observations_count = payload[:observations_count]
      identifications_for_others_count = payload[:identifications_for_others_count]
    end

    unless enabled?
      message = "Build test user is disabled by configuration"
      update_progress( login, status: "failed", progress: 100, message: message ) if login.present?
      return Result.new( success: false, message: message )
    end

    raise ArgumentError, "login is required" if login.blank?
    raise ArgumentError, "password is required" if password.blank?
    raise ArgumentError, "observations_count is required" if observations_count.nil?
    raise ArgumentError, "identifications_for_others_count is required" if identifications_for_others_count.nil?

    update_progress( login, status: "started", progress: 0 )
    now = Time.now
    observations_count = [observations_count.to_i, MAX_COUNT].min
    identifications_for_others_count = [identifications_for_others_count.to_i, MAX_COUNT].min
    # Create a confirmed, test-group user without sending welcome email.
    user = User.find_by_login( login )
    unless user
      user = User.new(
        login: login,
        email: "#{login}@inaturalist.org",
        password: password,
        password_confirmation: password,
        test_groups: TEST_GROUP_NAME
      )
      user.skip_welcome_email = true if user.respond_to?( :skip_welcome_email= )
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
    end

    # Pick a random set of observations to clone.
    observations = randomize_observations( count: observations_count )
    update_progress( login, status: "observations_selected", progress: 10 )

    # For each selected observation, clone the observation and its related records.
    identifications_from_own_obs = []
    cloned_observation_ids = []
    cloned_identification_ids = []
    observations_from_other_ids = []
    observations_with_identification_changes = []
    failed_observations = []
    failed_identifications = []
    if observations_count.positive? && observations.any?
      Observation.where( id: observations ).
        includes( :observation_photos, :observation_field_values, :annotations, :identifications, :comments ).
        find_each do | obs |
        begin
          original_user_id = obs.user_id

          cloned_obs = obs.dup
          cloned_obs.user_id = user.id
          cloned_obs.skip_indexing = true
          cloned_obs.skip_updates = true if cloned_obs.respond_to?( :skip_updates= )
          cloned_obs.uuid = nil if cloned_obs.respond_to?( :uuid )
          clone_note = "Cloned from obs #{obs.id} by user #{original_user_id}"
          if cloned_obs.description.to_s.strip.empty?
            cloned_obs.description = clone_note
          else
            cloned_obs.description = "#{cloned_obs.description}\n\n#{clone_note}"
          end
          if obs.latitude.present? && obs.longitude.present?
            cloned_obs.private_latitude = obs.latitude
            cloned_obs.private_longitude = obs.longitude
          end
          cloned_obs.save!
          cloned_observation_ids << cloned_obs.id

          if obs.observation_photos.any?
            photo_rows = obs.observation_photos.map do | op |
              {
                observation_id: cloned_obs.id,
                photo_id: op.photo_id,
                position: op.position,
                created_at: now,
                updated_at: now
              }
            end
            ObservationPhoto.insert_all( photo_rows )
            Observation.where( id: cloned_obs.id ).update_all(
              observation_photos_count: photo_rows.length
            )
          end

          obs.observation_field_values.each do | ofv |
            cloned_ofv = ofv.dup
            cloned_ofv.observation_id = cloned_obs.id
            cloned_ofv.user_id = ( ( ofv.user_id == original_user_id ) ? user.id : ofv.user_id )
            cloned_ofv.skip_updates = true if cloned_ofv.respond_to?( :skip_updates= )
            cloned_ofv.uuid = nil if cloned_ofv.respond_to?( :uuid )
            cloned_ofv.save!
          end

          obs.annotations.where( observation_field_value_id: nil ).each do | a |
            cloned_annotation = a.dup
            cloned_annotation.resource = cloned_obs
            cloned_annotation.user_id = ( ( a.user_id == original_user_id ) ? user.id : a.user_id )
            cloned_annotation.skip_indexing = true
            cloned_annotation.uuid = nil if cloned_annotation.respond_to?( :uuid )
            cloned_annotation.save!
          end

          obs.identifications.each do | ident |
            cloned_ident = ident.dup
            cloned_ident.observation_id = cloned_obs.id
            cloned_ident.user_id = ( ( ident.user_id == original_user_id ) ? user.id : ident.user_id )
            cloned_ident.skip_indexing = true
            cloned_ident.skip_updates = true if cloned_ident.respond_to?( :skip_updates= )
            cloned_ident.uuid = nil if cloned_ident.respond_to?( :uuid )
            cloned_ident.save!
            cloned_identification_ids << cloned_ident.id
            observations_with_identification_changes << cloned_obs.id
            identifications_from_own_obs << cloned_ident.id if ident.user_id == original_user_id
          end

          obs.comments.each do | comment |
            cloned_comment = comment.dup
            cloned_comment.parent = cloned_obs
            cloned_comment.user_id = ( ( comment.user_id == original_user_id ) ? user.id : comment.user_id )
            cloned_comment.skip_updates = true if cloned_comment.respond_to?( :skip_updates= )
            cloned_comment.uuid = nil if cloned_comment.respond_to?( :uuid )
            cloned_comment.save!
          end
        rescue => e
          failed_observations << { id: obs.id, error: e.message }
          puts "BuildTestUser.build_user observation_clone_failed id=#{obs.id} error=#{e.class}: #{e.message}"
          next
        end
      end
    end
    update_progress( login, status: "observations_assigned", progress: 50 )

    # Pick a random set of other identifications and clone them for the new user.
    indentifications = randomize_identifications( count: identifications_for_others_count )
    update_progress( login, status: "identifications_selected", progress: 60 )

    if identifications_for_others_count.positive? && indentifications.any?
      Identification.where( id: indentifications ).find_each do | ident |
        begin
          cloned_ident = ident.dup
          cloned_ident.user_id = user.id
          cloned_ident.skip_indexing = true
          cloned_ident.skip_updates = true if cloned_ident.respond_to?( :skip_updates= )
          cloned_ident.uuid = nil if cloned_ident.respond_to?( :uuid )
          cloned_ident.save!
          cloned_identification_ids << cloned_ident.id
          observations_from_other_ids << cloned_ident.observation_id
          observations_with_identification_changes << cloned_ident.observation_id
        rescue => e
          failed_identifications << { id: ident.id, error: e.message }
          puts "BuildTestUser.build_user identification_clone_failed id=#{ident.id} error=#{e.class}: #{e.message}"
          next
        end
      end
    end
    update_progress( login, status: "identifications_assigned", progress: 75 )

    all_observations = ( cloned_observation_ids + observations_from_other_ids ).uniq
    all_identifications = cloned_identification_ids.uniq
    observations_with_identification_changes.uniq!

    # Reindex changed observation and identification records.
    if all_observations.any?
      Observation.elastic_index!( ids: all_observations, wait_for_index_refresh: true )
      update_progress( login, status: "observations_re_indexed", progress: 85,
        message: "Re-indexed #{all_observations.count} observations" )
    end

    if observations_with_identification_changes.any?
      Observation.elastic_index!( ids: observations_with_identification_changes , wait_for_index_refresh: true )
      update_progress( login, status: "observations_from_identification_re_indexed", progress: 95,
        message: "Re-indexed observations for #{observations_with_identification_changes.count} identifications" )
    elsif all_identifications.any?
      Identification.elastic_index!( ids: all_identifications, wait_for_index_refresh: true )
      update_progress( login, status: "identifications_re_indexed", progress: 95,
        message: "Re-indexed #{all_identifications.count} identifications" )
    end

    # Reindex user and recompute counters for consistent search and stats.
    User.update_observations_counter_cache( user.id, skip_indexing: true )
    User.update_identifications_counter_cache( user.id )
    User.update_annotated_observations_counter_cache( user.id, skip_indexing: true )
    User.update_species_counter_cache( user.id, skip_indexing: true )
    user.reload
    user.elastic_index!
    update_progress( login, status: "user_re_indexed", progress: 100 )

    update_progress( login, status: "complete", progress: 100 )
    Result.new(
      success: true,
      message: [
        "Created user #{user.login}",
        "observations cloned: #{cloned_observation_ids.length}",
        "identifications cloned on those observations: #{identifications_from_own_obs.length}",
        "other identifications cloned: #{indentifications.length}"
      ].join( "; " ),
      user: user,
      details: {
        observations: cloned_observation_ids,
        identifications_from_own_obs: identifications_from_own_obs,
        indentifications: indentifications,
        observations_from_other_ids: observations_from_other_ids,
        failed_observations: failed_observations,
        failed_identifications: failed_identifications
      }
    )
  end

  def self.apply_updates( target_user_id:, update_action:, count: )
    unless enabled?
      return Result.new( success: false, message: "Build test user updates are disabled by configuration" )
    end

    target_user = User.find_by_id( target_user_id )
    unless target_user
      return Result.new( success: false, message: "Please select a valid user" )
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

    total_available = Observation.count
    if total_available < RANDOM_SAMPLE_THRESHOLD
      ids = Observation.order( Arel.sql( "RANDOM()" ) ).limit( count ).pluck( :id )
      puts(
        "BuildTestUser.randomize_observations random_scope total_available=#{total_available} " \
          "found=#{ids.size}"
      )
      return ids
    end

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

    total_available = Identification.count
    if total_available < RANDOM_SAMPLE_THRESHOLD
      ids = Identification.order( Arel.sql( "RANDOM()" ) ).limit( count ).pluck( :id )
      puts(
        "BuildTestUser.randomize_identifications random_scope total_available=#{total_available} " \
          "found=#{ids.size}"
      )
      return ids
    end

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
        notifier_user.skip_welcome_email = true if notifier_user.respond_to?( :skip_welcome_email= )
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
    log_entry = {
      login: login,
      status: status,
      progress: progress,
      message: message,
      updated_at: Time.now.utc
    }
    log_entries = Rails.cache.read( "build_test_user_progress_log" ) || []
    log_entries.unshift( log_entry )
    Rails.cache.write( "build_test_user_progress_log", log_entries, expires_in: 2.hours )
    Rails.cache.write(
      progress_key( login ),
      log_entry,
      expires_in: 2.hours
    )
  end

  def self.progress( login )
    Rails.cache.read( progress_key( login ) )
  end

  def self.progress_log
    Rails.cache.read( "build_test_user_progress_log" ) || []
  end

  private_class_method :ensure_notifier_users
end
