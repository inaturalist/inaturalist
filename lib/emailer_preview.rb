class EmailerPreview < MailView
  def updates_notification
    u = Update.last.subscriber
    updates = u.updates.all(:order => "id DESC", :limit => 50)
    Emailer.create_updates_notification(u, updates)
  end
end
