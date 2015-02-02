class EmailerController < ApplicationController

  before_filter :authenticate_user!

  def invite
    from = "#{CONFIG.site_name} <#{CONFIG.noreply_email}>"
    subject = "#REAL NAME wants you to join them on #{CONFIG.site_name}"
    @sending_user = current_user
    @sending_user_real_name = current_user.name.blank? ? current_user.login : current_user.name.split.first
    @observations = Observation.by(current_user.id).first(10)
  end

  def invite_send
    unless params[:email] && params[:email][:addresses] &&
        !params[:email][:addresses].blank?
      flash[:error] = "You forgot to enter any email addresses!"
      redirect_to :action => 'invite' and return
    end
    
    emails_allowed = 60 - current_user.invites.count(:conditions => ["created_at >= ?", 30.days.ago])
    addresses = params[:email][:addresses].to_s.split(',').map(&:strip).select{|e| e =~ Devise.email_regexp}
    @existing_users = User.where(email: addresses)
    @existing_invites = Invite.where(invite_address: addresses)
    
    # don't re-invite people
    @invited = addresses - (@existing_users.map(&:email) + @existing_invites.map(&:invite_address))
    
    # make sure they don't invite more than allowed
    @not_invited = @invited[emails_allowed..-1].try(:sort) || []
    @invited = @invited[0..emails_allowed].try(:sort) || []
    
    @invited.each do |address|
      Emailer.invite(address, params[:email], current_user).deliver_now
    end
  end
end
