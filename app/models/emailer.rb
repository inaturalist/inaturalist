#encoding: utf-8
class Emailer < ActionMailer::Base 
  helper :application
  helper :observations
  helper :taxa
  helper :users

  before_action :set_x_smtpapi_headers

  include Shared::MailerModule

  default from: "#{Site.default.try(:name)} <#{Site.default.try(:email_noreply)}>",
          reply_to: Site.default.try(:email_noreply)
  
  def project_invitation_notification(project_invitation)
    return unless project_invitation
    return if project_invitation.observation.user.prefers_no_email
    obs_str = project_invitation.observation.to_plain_s(:no_user => true, 
      :no_time => true, :no_place_guess => true)
    @subject = "#{subject_prefix} #{project_invitation.user.login} invited your " + 
      "observation of #{project_invitation.observation.species_guess} " + 
      "to #{project_invitation.project.title}"
    @project = project_invitation.project
    @observation = project_invitation.observation
    @user = project_invitation.observation.user
    set_locale
    @inviter = project_invitation.user
    mail(set_site_specific_opts.merge(
      :to => project_invitation.observation.user.email, 
      :subject => @subject
    ))
    reset_locale
  end
  
  def updates_notification(user, updates)
    return if user.blank? || updates.blank?
    return if user.email.blank?
    return if user.prefers_no_email
    @user = user
    set_locale
    @grouped_updates = UpdateAction.group_and_sort(updates, :skip_past_activity => true)
    mail(set_site_specific_opts.merge(
      :to => user.email,
      :subject => t(:updates_notification_email_subject, :prefix => subject_prefix, :date => Date.today)
    ))
    reset_locale
  end

  def new_message(message)
    @message = message
    @message = Message.find_by_id(message) unless message.is_a?(Message)
    return unless @message
    @user = @message.to_user
    set_locale
    return if @user.email.blank?
    return unless @user.prefers_message_email_notification
    return if @user.prefers_no_email
    return if @message.from_user.suspended?
    if fmc = @message.from_user_copy
      return if fmc.flags.where("resolver_id IS NULL").count > 0
    end
    mail(set_site_specific_opts.merge(:to => @user.email, :subject => "#{subject_prefix} #{@message.subject}"))
    reset_locale
  end

  def observations_export_notification(flow_task)
    @flow_task = flow_task
    @user = @flow_task.user
    set_locale
    return if @user.email.blank?
    return unless fto = @flow_task.outputs.first
    return unless fto.file?
    @file_url = FakeView.uri_join(root_url, fto.file.url)
    attachments[fto.file_file_name] = File.read(fto.file.path)
    mail(set_site_specific_opts.merge(
      to: @user.email,
      subject: t(:site_observations_export_from_date,
        site_name: @site.name,
        date: l(@flow_task.created_at.in_time_zone(@user.time_zone), format: :long))
    ))
    reset_locale
  end

  def observations_export_failed_notification(flow_task)
    @flow_task = flow_task
    @user = @flow_task.user
    set_locale
    return if @user.email.blank?
    @exports_url = FakeView.export_observations_url
    mail(set_site_specific_opts.merge(
      to: @user.email,
      subject: t(:site_observations_export_from_date,
        site_name: @site.name,
        date: l(@flow_task.created_at.in_time_zone(@user.time_zone), format: :long))
    ))
    reset_locale
  end

  def project_user_invitation(pui)
    return if pui.blank?
    @user = pui.invited_user
    @sender = pui.user
    @project = pui.project
    set_locale
    return if @user.email.blank?
    return unless @user.prefers_project_invitation_email_notification?
    return if @user.prefers_no_email?
    return if @project.user.suspended?
    mail(set_site_specific_opts.merge(
      :to => @user.email, 
      :subject => t(:user_invited_you_to_join_project, :user => @sender.try(:login), :project => @project.title)
    ))
    reset_locale
  end

  def user_updates_suspended(user)
    return if user.blank?
    @user = user
    set_locale
    return if @user.email.blank?
    return if @user.prefers_no_email?
    return if @user.suspended?
    @site_name = site_name
    mail(set_site_specific_opts.merge(
      to: @user.email,
      subject: t(:updates_suspension_email_subject, prefix: subject_prefix)
    ))
    reset_locale
  end

  # Send the user an email saying the bulk observation import encountered
  # an error.
  def bulk_observation_error(user, filename, error_details)
    @user = user
    set_locale
    @subject = "#{subject_prefix} #{t :were_sorry_but_your_bulk_import_of_filename_has_failed, :filename => filename}"
    @message       = error_details[:reason]
    @errors        = error_details[:errors]
    @field_options = error_details[:field_options]
    mail(set_site_specific_opts.merge(
      :to => "#{user.name} <#{user.email}>", :subject => @subject
    ))
    reset_locale
  end

  # Send the user an email saying the bulk observation import was successful.
  def bulk_observation_success(user, filename)
    @user = user
    set_locale
    @subject = "#{subject_prefix} #{t(:bulk_import_of_filename_is_complete, :filename => filename)}"
    @filename = filename
    mail(set_site_specific_opts.merge(
      :to => "#{user.name} <#{user.email}>", :subject => @subject
    ))
    reset_locale
  end

  def moimport_finished( mot, errors = {}, warnings = {} )
    @user = mot.user
    set_locale
    @subject = "#{subject_prefix} Mushroom Observer Import Finished"
    @errors = errors
    @warnings = warnings
    @exception = mot.exception
    mail(set_site_specific_opts.merge(
      :to => "#{@user.name} <#{@user.email}>", :subject => @subject
    ))
    reset_locale
  end

  def custom_email(user, subject, body)
    @user = user
    set_locale
    @subject = subject
    @body = body
    mail(set_site_specific_opts.merge(
      :to => "#{@user.name} <#{@user.email}>", :subject => @subject
    ))
    reset_locale
  end

  def photos_missing(user, grouped_photos)
    @user = user
    @site = user.site || Site.default
    @grouped_photos = grouped_photos
    set_locale
    @subject = I18n.t( "views.emailer.photos_missing.subject" )
    mail(set_site_specific_opts.merge(
      :to => "#{@user.name} <#{@user.email}>", :subject => @subject
    ))
    reset_locale
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
    set_site
    mail( set_site_specific_opts.merge(
      to: email,
      subject: t( "views.emailer.parental_consent.subject" )
    ) )
  end

  def user_parent_confirmation( user_parent )
    @user_parent = user_parent
    set_site
    mail( set_site_specific_opts.merge(
      to: user_parent.email,
      subject: t( "views.emailer.user_parent_confirmation.subject" )
    ) )
    reset_locale
  end

  def collection_project_changed_for_trusting_member( project_user )
    @project = project_user.project
    return unless @project.project_type == "collection"
    @user = project_user.user
    mail_with_defaults(
      subject: t(
        "views.emailer.collection_project_changed_for_trusting_member.subject",
        project: @project.title
      )
    )
  end

  def curator_application( user, application )
    set_site
    opts = set_site_specific_opts
    # Always send this email to iNat staff
    opts[:to] = Site.default.email_help.to_s.sub( "@", "+curator@" )
    opts[:from] = user.email || opts[:from]
    opts[:subject] = "Curator Application from #{user.login} (#{user.id})"
    @user = user
    @application = application
    mail( opts )
  end

  private
  def mail_with_defaults( defaults = {} )
    set_site
    opts = set_site_specific_opts.merge( defaults )
    opts[:to] ||= @user.name.blank? ? @user.email : "#{@user.name} <#{@user.email}>"
    set_locale
    mail( opts )
    reset_locale
  end

  def default_url_options
    opts = (Rails.application.config.action_mailer.default_url_options || {}).dup
    site = @user.try(:site) || @site || Site.default
    if site_uri = URI.parse( site.url )
      opts[:host] = site_uri.host
      if port = site_uri.port
        opts[:port] = port unless [80, 443].include?( port )
      end
    end
    opts
  end

  def subject_prefix
    site = @user.site || @site || Site.default
    "[#{site.name}]"
  end

  def site_name
    if site = @user.site
      site.name
    else
      @site.name
    end
  end

  def set_locale
    @locale_was = I18n.locale
    I18n.locale = if !@user.locale.blank?
      @user.locale
    elsif @user.site && !@user.site.preferred_locale.blank?
      @user.site.preferred_locale
    else
      I18n.default_locale
    end
    set_site
  end

  def reset_locale
    I18n.locale = @locale_was || I18n.default_locale
  end

  def set_site
    @site = @user ? @user.site : nil
    @site ||= Site.default
  end

  def set_site_specific_opts
    @site_name = @site.name
    # Can't have unicode chars in email headers
    {
      from: "#{@site.name.mb_chars.normalize(:kd).gsub(/[^\x00-\x7F]/n,'').to_s} <#{@site.email_noreply}>",
      reply_to: @site.email_noreply
    }
  end

  def set_x_smtpapi_headers
    @x_smtpapi_headers = {
      # This is an identifier specifying the Sendgrid Unsubscribe Group this
      # email belongs to. This assumes we're using one for all email sent from
      # the webapp
      asm_group_id: CONFIG.sendgrid && CONFIG.sendgrid.asm_group_ids ? CONFIG.sendgrid.asm_group_ids.default : nil,
      # We're having Sendgrid perform this substitution because ERB freaks out
      # when you put tags like this in a template
      sub: {
        "{{asm_group_unsubscribe_raw_url}}" => ['<%asm_group_unsubscribe_raw_url%>'.html_safe]
      }
    }
  end

end
