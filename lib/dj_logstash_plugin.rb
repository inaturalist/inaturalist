# require 'delayed_job'

class DJLogstashPlugin < Delayed::Plugin

  @@dj_logstash_plugin_loaded = false

  callbacks do |lifecycle|

    lifecycle.around(:invoke_job) do |job, *args, &block|
      begin
        start_time = Time.now
        Logstasher.delayed_job(job, "@timestamp": start_time)
        block.call(job, *args)
        end_time = Time.now
        Logstasher.delayed_job(job,
          "@timestamp": end_time,
          job_start_time: start_time,
          job_end_time: end_time,
          job_duration: (end_time.to_f - start_time.to_f).round(5))
      rescue Exception => error
        Logstasher.write_exception(error)
        raise error
      end
    end unless @@dj_logstash_plugin_loaded

    @@dj_logstash_plugin_loaded = true

  end

end