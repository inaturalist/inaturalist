class Emailer < ActionMailer::Base  
  helper :application
  helper :observations
  helper :taxa
  helper :users

  SUBJECT_PREFIX = "[#{CONFIG.site_name}]"

  default :from =>     "#{CONFIG.site_name} <#{CONFIG.noreply_email}>",
          :reply_to => CONFIG.noreply_email
  
  def invite(address, params, current_user) 
    Invite.create(:user => current_user, :invite_address => address)
    @subject = "#{SUBJECT_PREFIX} #{params[:sender_name]} wants you to join them on #{CONFIG.site_name}" 
    @personal_message = params[:personal_message]
    @sending_user = params[:sender_name]
    @current_user = current_user
    mail(:to => address) do |format|
      format.text
    end
  end
  
  def project_invitation_notification(project_invitation)
    return unless project_invitation
    return if project_invitation.observation.user.prefers_no_email
    obs_str = project_invitation.observation.to_plain_s(:no_user => true, 
      :no_time => true, :no_place_guess => true)
    @subject = "#{SUBJECT_PREFIX} #{project_invitation.user.login} invited your " + 
      "observation of #{project_invitation.observation.species_guess} " + 
      "to #{project_invitation.project.title}"
    @project = project_invitation.project
    @observation = project_invitation.observation
    @user = project_invitation.observation.user
    @inviter = project_invitation.user
    mail(:to => project_invitation.observation.user.email, :subject => @subject)
  end
  
  def updates_notification(user, updates)
    return if user.blank? || updates.blank?
    return if user.email.blank?
    return if user.prefers_no_email
    @user = user
    @grouped_updates = Update.group_and_sort(updates, :skip_past_activity => true)
    @update_cache = Update.eager_load_associates(updates)
    mail(
      :to => user.email,
      :subject => "#{SUBJECT_PREFIX} New updates, #{Date.today}"
    )
  end
end
