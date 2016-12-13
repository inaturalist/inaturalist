# require 'delayed_job'

class DJLogstashPlugin < Delayed::Plugin

  @@dj_logstash_plugin_loaded = false

  callbacks do |lifecycle|

    lifecycle.around(:invoke_job) do |job, *args, &block|
      begin
        Logstasher.delayed_job(job)
        start_time = Time.now
        block.call(job, *args)
        end_time = Time.now
        Logstasher.delayed_job(job,
          job_start_time: start_time,
          job_end_time: end_time,
          duration: (end_time.to_f - start_time.to_f) * 1000)
      rescue Exception => error
        Logstasher.write_exception(error)
        raise error
      end
    end unless @@dj_logstash_plugin_loaded

    @@dj_logstash_plugin_loaded = true

  end

end