# frozen_string_literal: true

class Emailer < ActionMailer::Base
  helper :application
  helper :observations
  helper :taxa
  helper :users

  before_action :set_x_smtpapi_headers

  include Shared::MailerModule

  default from: "#{Site.default.try( :name )} <#{Site.default.try( :email_noreply )}>",
    reply_to: Site.default.try( :email_noreply )

  def updates_notification( user, updates )
    return if user.blank? || updates.blank?
    return if user.email.blank?
    return if user.prefers_no_email
    return if user.email_suppressed_in_group?( EmailSuppression::TRANSACTIONAL_EMAILS )

    @user = user
    @grouped_updates = UpdateAction.group_and_sort(
      updates,
      skip_past_activity: true,
      viewer: @user
    )
    mail_with_defaults(
      to: user.email,
      subject: [:updates_notification_email_subject, { prefix: subject_prefix, date: Date.today }]
    )
  end

  def new_message( message )
    @message = message
    @message = Message.find_by_id( message ) unless message.is_a?( Message )
    return unless @message

    @user = @message.to_user
    return if @user.email.blank?
    return unless @user.prefers_message_email_notification
    return if @user.prefers_no_email
    return if @user.email_suppressed_in_group?( EmailSuppression::TRANSACTIONAL_EMAILS )
    return if @message.from_user.suspended?
    return if ( fmc = @message.from_user_copy ) && fmc.flags.where( "resolver_id IS NULL" ).count.positive?

    mail_with_defaults( to: @user.email, subject: "#{subject_prefix} #{@message.subject}" )
  end

  def observations_export_notification( flow_task )
    @flow_task = flow_task
    @user = @flow_task.user
    return if @user.email.blank?
    return unless ( fto = @flow_task.outputs.first )
    return unless fto.file?

    @file_url = fto.file.url
    attachments[fto.file_file_name] = File.read( fto.file.path )
    mail_with_defaults(
      to: @user.email,
      subject: [:site_observations_export_from_date, {
        site_name: site_name,
        date: l( @flow_task.created_at.in_time_zone( @user.time_zone ), format: :long )
      }]
    )
  end

  def observations_export_failed_notification( flow_task )
    @flow_task = flow_task
    @user = @flow_task.user
    return if @user.email.blank?

    mail_with_defaults(
      to: @user.email,
      subject: [:site_observations_export_from_date, {
        site_name: site_name,
        date: l( @flow_task.created_at.in_time_zone( @user.time_zone ), format: :long )
      }]
    )
  end

  def project_user_invitation( pui )
    return if pui.blank?

    @user = pui.invited_user
    @sender = pui.user
    @project = pui.project
    return if @user.email.blank?
    return unless @user.prefers_project_invitation_email_notification?
    return if @user.prefers_no_email?
    return if @user.email_suppressed_in_group?( EmailSuppression::TRANSACTIONAL_EMAILS )
    return if @project.user.suspended?

    mail_with_defaults(
      to: @user.email,
      subject: [
        :user_invited_you_to_join_project,
        { user: @sender.try( :login ), project: @project.title }
      ]
    )
  end

  def user_updates_suspended( user )
    return if user.blank?

    @user = user
    return if @user.email.blank?
    return if @user.prefers_no_email?
    return if @user.email_suppressed_in_group?( EmailSuppression::TRANSACTIONAL_EMAILS )
    return if @user.suspended?

    @site_name = site_name
    mail_with_defaults(
      to: @user.email,
      subject: [:updates_suspension_email_subject, { prefix: subject_prefix }]
    )
  end

  # Send the user an email saying the bulk observation import encountered
  # an error.
  def bulk_observation_error( user, filename, error_details )
    @user = user
    @message       = error_details[:reason]
    @errors        = error_details[:errors]
    @field_options = error_details[:field_options]
    mail_with_defaults(
      to: "#{user.name} <#{user.email}>",
      subject: [
        :were_sorry_but_your_bulk_import_of_filename_has_failed,
        { filename: filename }
      ]
    )
  end

  # Send the user an email saying the bulk observation import was successful.
  def bulk_observation_success( user, filename )
    @user = user
    @filename = filename
    mail_with_defaults(
      to: "#{user.name} <#{user.email}>",
      subject: [
        :bulk_import_of_filename_is_complete,
        { filename: filename }
      ]
    )
  end

  def custom_email( user, subject, body )
    @user = user
    @subject = subject
    @body = body
    mail_with_defaults( to: "#{@user.name} <#{@user.email}>", subject: @subject )
  end

  def photos_missing( user, grouped_photos )
    @user = user
    @grouped_photos = grouped_photos
    @subject = I18n.t( "views.emailer.photos_missing.subject" )
    mail_with_defaults( to: "#{@user.name} <#{@user.email}>", subject: @subject )
  end

  def notify_staff_about_blocked_user( user )
    @user = user
    @site = Site.default
    @subject = "User #{user.id} (#{user.login}) blocked by #{user.user_blocks_as_blocked_user.count} people"
    mail( set_site_specific_opts.merge(
      to: @site.email_help,
      subject: @subject
    ) )
  end

  def parental_consent( email )
    @site = Site.default
    mail_with_defaults(
      to: email,
      subject: ["views.emailer.parental_consent.subject"]
    )
  end

  def user_parent_confirmation( user_parent )
    @site = Site.default
    @user_parent = user_parent
    @user = @user_parent.parent_user
    mail_with_defaults(
      to: user_parent.email,
      subject: ["views.emailer.user_parent_confirmation.subject"]
    )
  end

  def collection_project_changed_for_trusting_member( project_user )
    @project = project_user.project
    return unless @project.project_type == "collection"

    @user = project_user.user
    mail_with_defaults(
      subject: [
        "views.emailer.collection_project_changed_for_trusting_member.subject",
        { project: @project.title }
      ]
    )
  end

  def curator_application( user, application )
    set_site
    opts = set_site_specific_opts
    # Always send this email to iNat staff
    opts[:to] = Site.default.email_help.to_s.sub( "@", "+curator@" )
    opts[:subject] = "Curator Application from #{user.login} (#{user.id})"
    @user = user
    @application = application
    # Small guard against not receiving applications if help@inat gets
    # unsubscribed from transactional emails
    @x_smtpapi_headers[:asm_group_id] = CONFIG&.sendgrid&.asm_group_ids&.account
    mail( opts )
  end

  def app_owner_application( user, application )
    set_site
    opts = set_site_specific_opts
    # Always send this email to iNat staff
    opts[:to] = Site.default.email_help.to_s.sub( "@", "+app_owner@" )
    opts[:subject] = "App Owner Application from #{user.login} (#{user.id})"
    @user = user
    @application = application
    mail( opts )
  end

  def welcome( user )
    @user = user
    @resource = @user
    set_locale
    mail( set_site_specific_opts.merge(
      to: user.email,
      subject: t( :welcome_to_inat, site_name: site_name )
    ) )
    reset_locale
  end

  def year_in_review( user, options = {} )
    @user = user
    return if @user&.email&.blank?
    # We are contemplating sending this to unconfirmed users
    # return unless @user&.confirmed?
    return if @user.prefers_no_email?
    return if @user.suspended?
    return if @user.email_suppressed_in_group?( EmailSuppression::NEWS_EMAILS )

    @year = Date.today.year
    global_year_statistic = YearStatistic.
      where( year: @year ).
      where( "user_id IS NULL" ).
      where( "site_id IS NULL" ).
      first
    unless global_year_statistic
      raise "Cannot send YIR email if YIR for this year does not exist"
    end

    @x_smtpapi_headers[:asm_group_id] = CONFIG&.sendgrid&.asm_group_ids&.news
    @force_default_site_url_options = true
    set_locale
    @shareable_image_url = global_year_statistic.
      shareable_image_for_locale( I18n.locale )&.
      url
    if options[:raise_on_missing_translations]
      without_english_fallback do
        # Set default options to raise errors on missing translation. I hope
        # there's a better way to do this but I haven't figured out one
        I18n.with_options( raise: true ) do | i18n |
          # Assign I18n instance with custom options to an instance var so it
          # can be accessed in views.
          @i18n = i18n
          mail( to: @user.email, subject: @i18n.t( :yir_email_subject, year: @year ) ) do | format |
            format.html { render layout: "emailer_dark" }
            format.text { render layout: "emailer_dark" }
          end
        end
      end
    else
      @i18n = I18n
      mail( to: user.email, subject: t( :yir_email_subject, year: @year ) ) do | format |
        format.html { render layout: "emailer_dark" }
        format.text { render layout: "emailer_dark" }
      end
    end
  ensure
    reset_locale
  end

  def observer_appeal( user, options = {} )
    @user = user

    geoip_latitude = options[:latitude]
    geoip_longitude = options[:longitude]
    return false unless geoip_latitude && geoip_longitude

    # Fetch species data
    current_month = Time.now.month
    filtered_species = get_filtered_species( geoip_latitude, geoip_longitude, current_month )

    # Return false if there are not enough filtered species
    return false if filtered_species.count < 4

    # Fetch nearby species and set month name
    filtered_species_ids = filtered_species.first( 4 ).map {| t | t["taxon"]["id"] }
    @nearby_species = Taxon.where( id: filtered_species_ids ).index_by( &:id ).values_at( *filtered_species_ids )

    # Mail settings
    set_locale
    mail(
      to: user.email,
      subject: "Can you find these species and share them on #{site_name}?",
      site_name: site_name
    )
    reset_locale
  end

  def error_observation( user, observation, options = {} )
    @user = user
    @observation = observation
    @errors = options[:errors]

    # Mail settings
    subject = "Will you improve your #{site_name} observation's value for science?"
    set_locale
    mail(
      to: user.email,
      subject: subject,
      site_name: site_name
    )
    reset_locale
  end

  def captive_observation( user, observation )
    @user = user
    @observation = observation

    # Fetch species data
    latitude = observation.latitude || observation.private_latitude || nil
    longitude = observation.longitude || observation.private_longitude || nil
    return false unless latitude

    current_month = Time.now.month
    tid = Taxon::ICONIC_TAXA.find {| t | t.name == "Plantae" }&.id
    filtered_species = get_filtered_species( latitude, longitude, current_month, taxon_id: tid )

    # Return false if there are not enough filtered species
    return false if filtered_species.count < 4

    # Fetch nearby species and set month name
    filtered_species_ids = filtered_species.first( 4 ).map {| t | t["taxon"]["id"] }
    @nearby_species = Taxon.where( id: filtered_species_ids ).index_by( &:id ).values_at( *filtered_species_ids )

    # Mail settings
    subject = "Will you try observing a wild species to share with #{site_name}?"
    set_locale
    mail(
      to: user.email,
      subject: subject,
      site_name: site_name
    )
    reset_locale
  end

  def first_observation( user, observation )
    @user = user
    @observation = observation

    most_recent_post = Post.where(
      parent_id: 1,
      parent_type: "Site"
    ).where( "title LIKE ?", "% News Highlights" ).
      order( published_at: :desc ).first
    url = @user.site&.url || Site.default.url
    @post_url = if most_recent_post
      FakeView.post_url( most_recent_post, host: url )
    end

    # Mail settings
    subject = "Congratulations on posting a Research Grade observation to #{site_name}!"
    set_locale
    mail(
      to: user.email,
      subject: subject,
      site_name: site_name
    )
    reset_locale
  end

  private

  def mail_with_defaults( defaults = {} )
    set_site
    opts = set_site_specific_opts.merge( defaults )
    opts[:to] ||= @user.name.blank? ? @user.email : "#{@user.name} <#{@user.email}>"
    set_locale
    # You can specify the subject as an array so it can be translated in the
    # correct locale
    if opts[:subject].is_a?( Array )
      opts[:subject] = if opts[:subject].length == 1
        t( opts[:subject][0] )
      else
        t( opts[:subject][0], **opts[:subject][1] )
      end
    end
    mail( opts )
    reset_locale
  end

  def subject_prefix
    site = @user.site || @site || Site.default
    "[#{site.name}]"
  end

  def site_name
    set_site
    @site.name
  end

  def set_locale( options = {} )
    # Don't bother if set_locale already ran
    return if @locale_was

    @locale_was = I18n.locale
    locale = if options[:force]
      options[:force]
    elsif !@user&.locale&.blank?
      @user&.locale
    elsif @user&.site && !@user&.site&.preferred_locale&.blank?
      @user&.site&.preferred_locale
    end
    I18n.locale = normalize_locale( locale )
    set_site
  end

  def reset_locale
    I18n.locale = @locale_was || I18n.default_locale
    @locale_was = nil
  end

  # rubocop:disable Naming/MemoizedInstanceVariableName
  def set_site
    @site ||= @user ? @user.site : nil
    @site ||= Site.default
  end
  # rubocop:enable Naming/MemoizedInstanceVariableName

  def set_site_specific_opts
    @site_name = @site.name
    {
      from: "#{@site.name} <#{@site.email_noreply}>",
      reply_to: @site.email_noreply
    }
  end

  def set_x_smtpapi_headers
    @x_smtpapi_headers = {
      # This is an identifier specifying the Sendgrid Unsubscribe Group this
      # email belongs to. This assumes we're using one for all email sent from
      # the webapp
      asm_group_id: CONFIG&.sendgrid&.asm_group_ids&.default,
      # We're having Sendgrid perform this substitution because ERB freaks out
      # when you put tags like this in a template
      sub: {
        "{{asm_group_unsubscribe_raw_url}}" => ["<%asm_group_unsubscribe_raw_url%>".html_safe]
      },
      # Sendgrid IP pools allow us to partition delivery between different IPs
      # if we need to preserve the reputation of one while sending a lot or
      # riskier emails from another
      ip_pool: CONFIG&.sendgrid&.primary_ip_pool
    }
  end

  def get_filtered_species( latitude, longitude, current_month, taxon_id: nil )
    dangerous_taxa = CONFIG.dangerous_taxa_list_id.blank? ? nil : CONFIG.dangerous_taxa_list_id
    query_params = {
      verifiable: true,
      lat: latitude,
      lng: longitude,
      month: current_month,
      radius: 50,
      not_in_list_id: dangerous_taxa
    }
    query_params[:taxon_id] = taxon_id if taxon_id
    species = INatAPIService.observations_species_counts( query_params ).results

    # Filter species based on criteria
    iconic_taxon_names = ["Aves", "Plantae", "Insecta", "Mammalia"]
    filtered_species = iconic_taxon_names.map do | iconic_taxon_name |
      preferred_species = species.find do | s |
        s["taxon"]["iconic_taxon_name"] == iconic_taxon_name &&
          s["taxon"]["rank"] == "species" &&
          s["taxon"]["preferred_common_name"].present?
      end
      preferred_species ||= species.find do | s |
        s["taxon"]["iconic_taxon_name"] == iconic_taxon_name &&
          s["taxon"]["rank"] == "species"
      end
      preferred_species ||= species.find do | s |
        s["taxon"]["iconic_taxon_name"] == iconic_taxon_name
      end
      preferred_species
    end.compact

    # If there are not enough species, fill in with additional species
    if species.count > 4 && filtered_species.count < 4
      species.each do | s |
        break if filtered_species.length >= 4

        unless filtered_species.any? {| fs | fs["taxon"]["id"] == s["taxon"]["id"] }
          filtered_species << s
        end
      end
    end
    filtered_species
  end
end
