# only allow certain jobs to query replicas
def job_can_use_replica( job )
  return true if job.handler_yaml.is_a?( ObservationsExportFlowTask )
  unless job.handler_yaml.respond_to?(:object) && job.handler_yaml.respond_to?(:method_name)
    return false
  end
  class_name = ( job.handler_yaml.object.kind_of?( ActiveRecord::Base ) ?
    job.handler_yaml.object.class.name : job.handler_yaml.object.name ) rescue nil
  object_method = "#{class_name}::#{job.handler_yaml.method_name}"
  return true if object_method == "Identification::run_update_curator_identification"
  return true if object_method == "Identification::update_categories_for_observation"
  return true if object_method == "CheckList::refresh_listed_taxon"
  return true if object_method == "CheckList::refresh"
  return true if object_method == "Observation::notify_subscribers_of"
  return true if object_method == "Identification::notify_subscribers_of"
  return true if object_method == "UpdateAction::email_updates_to_user"
  false
end

class DJMakaraPlugin < Delayed::Plugin

  callbacks do |lifecycle|

    lifecycle.around(:invoke_job) do |job, *args, &block|
      using_replica = job_can_use_replica(job)
      begin
        if using_replica && ActiveRecord::Base.connection.respond_to?(:enable_context_refresh)
          # enable use of replica DBs
          ActiveRecord::Base.connection.enable_replica
          ActiveRecord::Base.connection.enable_context_refresh
          Makara::Context.release_all
        end
        block.call(job, *args)
      ensure
        if using_replica && ActiveRecord::Base.connection.respond_to?(:enable_context_refresh)
          ActiveRecord::Base.connection.disable_replica
          ActiveRecord::Base.connection.disable_context_refresh
          Makara::Context.release_all
        end
      end
    end

  end

end