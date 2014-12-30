class EmailerPreview < MailView
  def updates_notification
    set_locale
    set_user
    @user ||= Update.last.subscriber
    updates = @user.updates.all(:order => "id DESC", :limit => 50, :include => [:subscriber, :resource_owner])
    Emailer.updates_notification(@user, updates)
  end

  def new_message
    set_locale
    m = if message_id = @rack_env["QUERY_STRING"].to_s[/message_id=([^&]+)/, 1]
      Message.find_by_id(message_id)
    end
    m ||= Message.last
    Emailer.new_message(m)
  end

  def observations_export_notification
    set_locale
    ft = if (ftid = @rack_env["QUERY_STRING"].to_s[/flow_task_id=([^&]+)/, 1])
      FlowTask.find_by_id(ftid)
    end
    ft ||= ObservationsExportFlowTask.includes(:outputs).where("flow_task_resources.id IS NOT NULL").last
    Emailer.observations_export_notification(ft)
  end

  def project_user_invitation
    set_locale
    pui = if (id = @rack_env["QUERY_STRING"].to_s[/id=([^&]+)/, 1])
      ProjectUserInvitation.find_by_id(id)
    end
    pui ||= ProjectUserInvitation.last
    Emailer.project_user_invitation(pui)
  end

  def confirmation_instructions
    # locale is determined by the user's locale
    set_user
    @user ||= User.first
    DeviseMailer.devise_mail(@user, :confirmation_instructions)
  end

  private
  def set_user
    @user = if login = @rack_env["QUERY_STRING"].to_s[/login=([^&]+)/, 1]
      User.find_by_login(login)
    end
  end

  def set_locale
    if locale = @rack_env["QUERY_STRING"].to_s[/locale=([^&]+)/, 1]
      I18n.locale = locale
    end
  end
end
