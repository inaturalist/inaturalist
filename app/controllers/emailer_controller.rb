class EmailerController < ApplicationController

  before_filter :authenticate_user!

  def invite
    from = "#{APP_CONFIG[:site_name]} <#{APP_CONFIG[:noreply_email]}>"
    subject = "#REAL NAME wants you to join them on iNaturalist"
    @sending_user = current_user
    @sending_user_real_name = "YOUR REAL NAME"
    @observations = Observation.by(current_user.id).first(10)
  end

  def invite_send
    unless params[:email] && params[:email][:addresses] &&
        !params[:email][:addresses].blank?
      flash[:error] = "You forgot to enter any email addresses!"
      redirect_to :action => 'invite' and return
    end
    
    emails_allowed = 60 - current_user.invites.count(:conditions => ["created_at >= ?", 30.days.ago])
    addresses = params[:email][:addresses].to_s.split(',').map(&:strip).select{|e| e =~ Authentication.email_regex}
    @existing_users = User.all(:conditions => ["email IN (?)", addresses])
    @existing_invites = Invite.all(:conditions => ["invite_address IN (?)", addresses])
    
    # don't re-invite people
    @invited = addresses - (@existing_users.map(&:email) + @existing_invites.map(&:invite_address))
    
    # make sure they don't invite more than allowed
    @not_invited = @invited[emails_allowed..-1].try(:sort) || []
    @invited = @invited[0..emails_allowed].try(:sort) || []
    
    @invited.each do |address|
      Emailer.deliver_invite(address, params[:email], current_user)
    end
  end
end
