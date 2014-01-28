class Emailer < ActionMailer::Base  
  helper :application
  helper :observations
  helper :taxa
  helper :users

  default :from =>     "#{CONFIG.site_name} <#{CONFIG.noreply_email}>",
          :reply_to => CONFIG.noreply_email
  
  def invite(address, params, user) 
    Invite.create(:user => user, :invite_address => address)
    @user = user
    @subject = "#{subject_prefix} #{params[:sender_name]} wants you to join them on #{CONFIG.site_name}" 
    @personal_message = params[:personal_message]
    @sending_user = params[:sender_name]
    mail(:to => address) do |format|
      format.text
    end
  end
  
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
    mail(:to => project_invitation.observation.user.email, :subject => @subject)
    reset_locale
  end
  
  def updates_notification(user, updates)
    return if user.blank? || updates.blank?
    return if user.email.blank?
    return if user.prefers_no_email
    @user = user
    set_locale
    @grouped_updates = Update.group_and_sort(updates, :skip_past_activity => true)
    @update_cache = Update.eager_load_associates(updates)
    mail(
      :to => user.email,
      :subject => t(:updates_notification_email_subject, :prefix => subject_prefix, :date => Date.today)
    )
    reset_locale
  end

  def new_message(message)
    @message = message
    @message = Message.find_by_id(message) unless message.is_a?(Message)
    @user = @message.to_user
    set_locale
    return if @user.email.blank?
    return unless @user.prefers_message_email_notification
    return if @user.prefers_no_email
    return if @message.from_user.suspended?
    if fmc = @message.from_user_copy
      return if fmc.flags.where("resolver_id IS NULL").count > 0
    end
    mail(:to => @user.email, :subject => "#{subject_prefix} #{@message.subject}")
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
    mail :to => @user.email, :subject => t(:site_observations_export_from_date, :site_name => SITE_NAME, :date => l(@flow_task.created_at.in_time_zone(@user.time_zone), :format => :long))
    reset_locale
  end

  private
  def default_url_options
    opts = Rails.application.config.action_mailer.default_url_options.dup
    return opts unless @user && @user.site
    opts[:host] = URI.parse(@user.site.url).host
    opts[:port] = URI.parse(@user.site.url).port
    opts
  end

  def subject_prefix
    if site = @user.site
      "[#{site.name}]"
    else
      "[#{CONFIG.site_name}]"
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
  end

  def reset_locale
    I18n.locale = @locale_was || I18n.default_locale
  end
end
