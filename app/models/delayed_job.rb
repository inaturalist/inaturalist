class Delayed::Backend::ActiveRecord::Job
  def self.possibly_active
    # Delayed::Job.order(created_at: :desc).limit(10)
    results = self.where("locked_by IS NOT NULL").
      where("locked_at > ?", Delayed::Worker.max_run_time.ago).
      where("failed_at IS NULL").
      order(locked_at: :desc)
    active_jobs = [ ]
    # remove any duplicates. Those would be the same DJ
    # unique_process name with some older, expired PID
    results.each do |r|
      unless active_jobs.detect{ |j| j.unique_process == r.unique_process }
        active_jobs << r
      end
    end
    active_jobs.reverse
  end

  def self.failed
    Delayed::Job.
      where("failed_at IS NOT NULL OR attempts > 0 OR last_error IS NOT NULL").
      order(failed_at: :desc)
  end

  def self.pending
    Delayed::Job.where("run_at > ? OR attempts = 0", Time.now).order(run_at: :asc)
  end

  def paperclip?
    queue == "paperclip"
  end

  def bulk_observation_file?
    handler_yaml.is_a?(BulkObservationFile)
  end

  def observations_export?
    handler_yaml.is_a?(ObservationsExportFlowTask)
  end

  def flow_task?
    handler_yaml.kind_of?(FlowTask)
  end

  def unique_process
    locked_by.match(/(.*) pid/)[1] if locked_by
  end

  def process_name
    locked_by.match(/delayed_job.(.*) host/)[1] if locked_by
  end

  def host
    locked_by.match(/ host:([^ ]*)/)[1] if locked_by
  end

  def pid
    locked_by.match(/ pid:(.*)/)[1] if locked_by
  end

  def handler_yaml
    @handler_yaml ||= (YAML.load(handler) rescue nil)
  end

  def acts_on_object
    return if paperclip? || bulk_observation_file?
    return handler_yaml if flow_task?
    handler_yaml.object if handler_yaml.respond_to?(:object)
  end

  def acts_on_method
    return if paperclip? || bulk_observation_file?
    return "run" if flow_task?
    return unless handler_yaml.respond_to?(:method_name)
    return handler_yaml.args.first if handler_yaml.method_name.to_s == "send"
    handler_yaml.method_name
  end

  def acts_on_args
    return { query: handler_yaml.query } if observations_export?
    return if flow_task?
    if bulk_observation_file?
      return {
        observation_file: (handler_yaml.observation_file if handler_yaml.respond_to?(:observation_file)),
        user_id: (handler_yaml.user.id if handler_yaml.user),
        project_id: (handler_yaml.project.id if handler_yaml.project),
        csv_options: (handler_yaml.csv_options if handler_yaml.respond_to?(:csv_options))
      }
    end
    return handler_yaml.job_data["arguments"] if paperclip?
    return unless handler_yaml.respond_to?(:method_name)
    return handler_yaml.args[1,] if handler_yaml.method_name.to_s == "send"
    handler_yaml.args
  end

  def dashboard_info
    info = {
      id: id,
      host: host,
      pid: pid,
      process: unique_process,
      attempts: attempts
    }
    info[:object] = if paperclip?
      acts_on_args.first.constantize
    elsif acts_on_object.kind_of?(ActiveRecord::Base)
      "&lt;#{ acts_on_object.class.name } :: #{ acts_on_object.id }&gt;"
    else
      acts_on_object
    end
    info[:method] = paperclip? ? "DelayedPaperclip" : acts_on_method
    info[:arguments] = unless acts_on_args.blank?
      if acts_on_args.is_a?(Array) && acts_on_args.length == 1
        acts_on_args.first
      else
        acts_on_args
      end
    end
    info[:unique_hash] = unique_hash
    info[:locked_at] = locked_at.to_s(:long) if locked_at
    info[:created_at] = created_at.to_s(:long) if created_at
    info[:failed_at] = failed_at.to_s(:long) if failed_at
    if last_error
      info[:last_error] = "<br><br>" + last_error[0...1000].gsub("\n", "<br>")
    end
    info
  end
end
