class EmailerController < ApplicationController

  before_filter :login_required

  def invite
    from = "The iNaturalist Community <no-reply@inaturalist.org>"
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

    require "csv"
    sent_to = ""
    users_with_email = []
    already_emailed = []
    begin
      email_reg = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
      emails_allowed = 60 - Invite.count(
        :conditions => ["user_id = ? AND DATE_SUB(CURDATE(),INTERVAL 30 DAY) <= created_at",current_user.id])
      CSV::Reader.parse(params[:email][:addresses]) do |row|
        row.each do |address|
          if address and email_reg.match(email = address.strip)
            if !Invite.exists?(:invite_address => email) and !User.exists?(:email =>email)
              if emails_allowed >= 0
                Emailer.deliver_invite(email, params[:email], current_user)
                if sent_to != ""
                  sent_to << ", " + email
                else
                  sent_to << " " + email
                end
                emails_allowed -= 1
              end
            else
              if User.exists?(:email =>email)
                users_with_email << email
              else
                already_emailed << email
              end
            end
          end
        end
      end
    rescue CSV::IllegalFormatError
      flash[:error] = "Your email address list returned an illegal format exception. " +
        "If the problem persists after you remove any strange characters, " +
        "please email us the email list and we'll figure out the problem"
      render :contoller => 'emailer', :action => 'invite'
      return
    end

    if sent_to != ""
      flash[:notice] = "We sent email(s) to#{sent_to}"+
        " You have #{emails_allowed} emails remaining at this time. Thanks for spreading the word!"
    else
      flash[:notice] = "We did not send any invites."+
      " If you believe this is an error, please let us know."
    end


    already_emailed.each_with_index do |email, index|
      if index == 0
        flash[:notice] += "<br /><br /> The folowing email address(es) have already been invited but do not have accounts:"+
          " #{email}"
      else
        flash[:notice] += ", #{email}"
      end
    end

    users_with_email.each_with_index do |email, index|
      if index == 0
        flash[:notice] += "<br /><br /> The folowing email address(es) already have accounts with iNaturalist and were not sent invites: #{email}"
      else
        flash[:notice] += ", #{email}"
      end
    end

    redirect_to :action => "invite"
  end
end
