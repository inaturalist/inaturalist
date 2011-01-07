class ResquePaperclipJob
  @queue = :paperclip

  def self.perform(instance_klass, instance_id, attachment_name)
    instance = instance_klass.constantize.find(instance_id)

    process_job(instance, attachment_name) do
      instance.send(attachment_name).reprocess!
      instance.send("#{attachment_name}_processed!")
    end
  end
  
  private
  def self.process_job(instance, attachment_name)
    instance.send(attachment_name).job_is_processing = true
    yield
    instance.send(attachment_name).job_is_processing = false        
  end
end