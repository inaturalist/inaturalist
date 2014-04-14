class EmailerPreview < MailView
  def updates_notification
    u = if login = @rack_env["QUERY_STRING"].to_s[/login=([^&]+)/, 1]
      User.find_by_login(login)
    end
    u ||= Update.last.subscriber
    updates = u.updates.all(:order => "id DESC", :limit => 50, :include => [:subscriber, :resource_owner])
    Emailer.updates_notification(u, updates)
  end

  def new_message
    m = if message_id = @rack_env["QUERY_STRING"].to_s[/message_id=([^&]+)/, 1]
      message.find_by_id(message_id)
    end
    m ||= Message.last
    Emailer.new_message(m)
  end

  def observations_export_notification
    ft = if (ftid = @rack_env["QUERY_STRING"].to_s[/flow_task_id=([^&]+)/, 1])
      FlowTask.find_by_id(ftid)
    end
    ft ||= ObservationsExportFlowTask.includes(:outputs).where("flow_task_resources.id IS NOT NULL").last
    Emailer.observations_export_notification(ft)
  end
end
