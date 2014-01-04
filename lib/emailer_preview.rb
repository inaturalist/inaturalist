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
    Emailer.new_message(Message.last)
  end

  def observations_export_notification
    ft = ObservationsExportFlowTask.includes(:outputs).where("flow_task_resources.id IS NOT NULL").first
    Emailer.observations_export_notification(ft)
  end
end
