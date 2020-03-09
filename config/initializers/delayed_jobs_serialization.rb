# Extend ActiveRecord::Base to add an attribute which can be used to change
# how the model is serialized to YAML. This attribute is only meant to be set
# during the enqueuing of delayed jobs. It will serialize only the primary key
# to minimize the size of the delayed job handler attribute
module ActiveRecord
  class Base
    attr_accessor :dj_serialize_minimal

    def encode_with(coder)
      if !self.class.primary_key || !self.class.primary_key.is_a?( String ) || !dj_serialize_minimal
        super
        return
      end
      coder.map = {
        "attributes" => {
          self.class.primary_key => self[self.class.primary_key].to_s
        }
      }
    end

  end
end

module Delayed
  module Backend
    module Base
      module ClassMethods

        # Add a job to the queue
        def enqueue(*args)
          job_options = Delayed::Backend::JobPreparer.new(*args).prepare
          payload_object = job_options[:payload_object]
          # check if the payload object is an instance of ActiveRecord::Base with a
          # single column primary key, and enables the setting of dj_serialize_minimal
          is_ar_instance = payload_object && payload_object.is_a?( Delayed::PerformableMethod ) &&
            payload_object.object && payload_object.object.is_a?(::ActiveRecord::Base) &&
            payload_object.respond_to?("dj_serialize_minimal=")

          # enable minimal serialization on the instancee
          if is_ar_instance
            payload_object.object.dj_serialize_minimal = true
          end
          
          job = enqueue_job(job_options)
          
          # disable minimal serialization on the instancee
          if is_ar_instance
            payload_object.object.dj_serialize_minimal = nil
          end

          job
        end

      end
    end
  end
end

