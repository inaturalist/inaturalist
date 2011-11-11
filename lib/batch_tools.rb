# Just something to tide us over until we get around to upgrading rails...
module BatchTools
  module ActiveRecord
    def self.included(ar)
      ar.extend ClassMethods
    end

    module ClassMethods
      def do_in_batches(options = {}, &block)
        batch_size = options.delete(:batch_size) || 1000
        full_count = self.count(options)
        (full_count / batch_size + 1).times do |batch|
          Rails.logger.info "[INFO #{Time.now}] Working on #{self} batch " +
            "#{batch+1} of #{full_count / batch_size + 1} (batch size: #{batch_size})"
          work_on_batch(batch, batch_size, options, &block)
        end
      end
      
      private
      def work_on_batch(batch, batch_size, options = {}, &block)
        options.merge!(:offset => batch * batch_size, :limit => batch_size)
        all(options).each do |item|
          yield(item)
          GC.start
          item = nil
        end
      end
    end
  end
end
ActiveRecord::Base.send(:include, BatchTools::ActiveRecord)
