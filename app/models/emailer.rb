class Emailer < ActionMailer::Base  
  helper :application
  helper :observations
  helper :taxa
  helper :users
  
  def invite(address, params, current_user) 
    setup_email
    Invite.create(:user => current_user, :invite_address => address)
    content_type "text/plain"
    recipients address
    @subject << "#{params[:sender_name]} wants you to join them on iNaturalist" 
    @body = {
      :personal_message => params[:personal_message], 
      :sending_user => params[:sender_name], 
      :current_user => current_user
    }
    template "invite_send" 
  end
  
  def comment_notification(comment)
    parent = comment.parent
    return unless parent && parent.respond_to?(:user)
    return unless parent.user
    return if parent.user.prefers_no_email
    setup_email
    recipients parent.user.email
    parent_str = parent.to_plain_s(:no_user => true, :no_time => true, 
      :no_place_guess => true)
    @subject << "#{comment.user.login} commented on your " + 
      parent.class.to_s.underscore.humanize.downcase + 
      " \"#{parent_str})\""
    
    # I wish the parent_url thing wasn't necessary, but I can't seem to figure
    # out how to mix ActionController::PolymorphicRoutes into whatever version
    # of ActionView::Base ActionMailer seems to use.
    if parent.is_a?(Post)
      parent_url = post_url(parent.user.login, parent)
    else
      parent_url = polymorphic_url(parent)
    end
    @body = {
      :comment => comment,
      :user => parent.user,
      :commenter => comment.user,
      :parent_url => parent_url
    }
  end
  
  def identification_notification(identification)
    return if identification.observation.user.prefers_no_email
    setup_email
    recipients identification.observation.user.email
    obs_str = identification.observation.to_plain_s(:no_user => true, 
      :no_time => true, :no_place_guess => true)
    @subject << "#{identification.user.login} added an ID to your " + 
      "observation \"#{obs_str})\""
    @body = {
      :identification => identification,
      :observation => identification.observation,
      :user => identification.observation.user,
      :identifier => identification.user
    }
  end
  
  def project_invitation_notification(project_invitation)
    return unless project_invitation
    return if project_invitation.observation.user.prefers_no_email
    setup_email
    recipients project_invitation.observation.user.email
    obs_str = project_invitation.observation.to_plain_s(:no_user => true, 
      :no_time => true, :no_place_guess => true)
    @subject << "#{project_invitation.user.login} invited your " + 
      "observation of #{project_invitation.observation.species_guess} " + 
      "to #{project_invitation.project.title}"
    @body = {
      :project => project_invitation.project,
      :observation => project_invitation.observation,
      :user => project_invitation.observation.user,
      :inviter => project_invitation.user
    }
  end
  
  def updates_notification(user, updates)
    return if user.blank? || updates.blank?
    return if user.email.blank?
    return if user.prefers_no_email
    setup_email
    recipients user.email
    @subject << "New updates, #{Date.today}"
    @body = {
      :user => user,
      :grouped_updates => Update.group_and_sort(updates, :skip_past_activity => true),
      :update_cache => Update.eager_load_associates(updates)
    }
  end
  
  protected
    def setup_email
      from    "#{APP_CONFIG[:site_name]} <#{APP_CONFIG[:noreply_email]}>"
      reply_to APP_CONFIG[:noreply_email]
      subject "[#{APP_CONFIG[:site_name]}] "
      sent_on Time.now
    end
end
