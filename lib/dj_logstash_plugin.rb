# require 'delayed_job'

class DJLogstashPlugin < Delayed::Plugin

  @@dj_logstash_plugin_loaded = false

  callbacks do |lifecycle|

    lifecycle.around(:invoke_job) do |job, *args, &block|
      begin
        Logstasher.delayed_job(job)
        block.call(job, *args)
      rescue Exception => error
        Logstasher.write_exception(error)
        raise error
      end
    end unless @@dj_logstash_plugin_loaded

    @@dj_logstash_plugin_loaded = true

  end

end