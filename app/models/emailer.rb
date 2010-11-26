class Emailer < ActionMailer::Base  
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
    return unless comment.parent.respond_to?(:user)
    return unless comment.parent.user
    setup_email
    recipients comment.parent.user.email
    parent_str = comment.parent.to_plain_s(:no_user => true, :no_time => true, 
      :no_place_guess => true)
    @subject << "#{comment.user.login} commented on your " + 
      comment.parent.class.to_s.underscore.humanize.downcase + 
      " \"#{parent_str})\""
    
    # I wish the parent_url thing wasn't necessary, but I can't seem to figure
    # out how to mix ActionController::PolymorphicRoutes into whatever version
    # of ActionView::Base ActionMailer seems to use.
    if comment.parent.is_a?(Post)
      parent_url = post_url(comment.parent.user.login, comment.parent)
    else
      parent_url = polymorphic_url(comment.parent)
    end
    @body = {
      :comment => comment,
      :user => comment.parent.user,
      :commenter => comment.user,
      :parent_url => parent_url
    }
  end
  
  def identification_notification(identification)
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
  
  protected
    def setup_email
      from    "iNaturalist.org <#{APP_CONFIG[:noreply_email]}>"
      reply_to APP_CONFIG[:noreply_email]
      subject "[#{APP_CONFIG[:site_name]}] "
      sent_on Time.now
    end
end
