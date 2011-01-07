module Delayed
  module Paperclip
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def process_in_background(name)
        include InstanceMethods

        define_method "#{name}_changed?" do
          attachment_has_changed?(name)
        end

        define_method "halt_processing_for_#{name}" do
          return unless self.send("#{name}_changed?")

          false # halts processing
        end

        define_method "enqueue_job_for_#{name}" do
          return unless self.send("#{name}_changed?")

          if delayed_job?
            Delayed::Job.enqueue DelayedPaperclipJob.new(self.class.name, read_attribute(:id), name.to_sym)
          elsif resque?
            Resque.enqueue(ResquePaperclipJob, self.class.name, read_attribute(:id), name.to_sym)
          end
        end

        define_method "#{name}_processed!" do
          return unless column_exists?(:"#{name}_processing")
          return unless self.send(:"#{name}_processing?")

          self.send("#{name}_processing=", false)
          self.save(false)
        end

        define_method "#{name}_processing!" do
          return unless column_exists?(:"#{name}_processing")
          return if self.send(:"#{name}_processing?")
          return unless self.send(:"#{name}_changed?")

          self.send("#{name}_processing=", true)
        end

        self.send("before_#{name}_post_process", :"halt_processing_for_#{name}")

        before_save :"#{name}_processing!"
        after_save  :"enqueue_job_for_#{name}"
      end
    end

    module InstanceMethods
      PAPERCLIP_ATTRIBUTES = ['_file_size', '_file_name', '_content_type', '_updated_at']
      
      def attachment_has_changed?(name)
        PAPERCLIP_ATTRIBUTES.each do |attribute|
          full_attribute = "#{name}#{attribute}_changed?".to_sym

          next unless self.respond_to?(full_attribute)
          return true if self.send("#{name}#{attribute}_changed?")
        end

        false
      end

      def delayed_job?
        defined? Delayed::Job
      end

      def resque?
        defined? Resque
      end
      
      def column_exists?(column)
        self.class.columns_hash.has_key?(column.to_s)
      end
    end      
  end
end

module Paperclip
  class Attachment
    attr_accessor :job_is_processing

    def url_with_processed style = default_style, include_updated_timestamp = true
      return url_without_processed style, include_updated_timestamp unless @instance.respond_to?(:column_exists?)
      return url_without_processed style, include_updated_timestamp if job_is_processing

      if !@instance.column_exists?(:"#{@name}_processing")
        url_without_processed style, include_updated_timestamp
      else
        if !@instance.send(:"#{@name}_processing?")
          url_without_processed style, include_updated_timestamp
        else
          if @instance.send(:"#{@name}_changed?")
            url_without_processed style, include_updated_timestamp
          else
            interpolate(@default_url, style)
          end
        end
      end
    end
    
    alias_method_chain :url, :processed
  end
end