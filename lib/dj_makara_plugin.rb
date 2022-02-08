# only allow certain jobs to query replicas
def job_can_use_replica( job )
  job.handler_yaml.object == Identification &&
    job.handler_yaml.method_name == :run_update_curator_identification
end

class DJMakaraPlugin < Delayed::Plugin

  callbacks do |lifecycle|

    lifecycle.around(:invoke_job) do |job, *args, &block|
      using_replica = job_can_use_replica(job)
      begin
        if using_replica && ActiveRecord::Base.connection.respond_to?(:enable_replica)
          ActiveRecord::Base.connection.enable_replica
          ActiveRecord::Base.connection.enable_context_refresh
          Makara::Context.release_all
        end
        block.call(job, *args)
      ensure
        if using_replica && ActiveRecord::Base.connection.respond_to?(:disable_replica)
          ActiveRecord::Base.connection.disable_replica
          ActiveRecord::Base.connection.disable_context_refresh
          Makara::Context.release_all
        end
      end
    end

  end

end