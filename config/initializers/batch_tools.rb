# Just something to tide us over until we get around to upgrading rails...
module BatchTools
  module ActiveRecord
    def self.included(ar)
      ar.extend ClassMethods
    end

    module ClassMethods
      def do_in_batches(options = {}, &block)
        batch_size = options.delete(:batch_size) || 1000
        count_options = options.reject {|k,v| k.to_s == 'order'}
        if count_options[:select]
          if distinct = count_options[:select][/DISTINCT \(.+?\)/, 0]
            count_options[:select] = distinct
          elsif distinct = count_options[:select][/DISTINCT ON \((.+?)\)/, 1]
            count_options[:select] = "DISTINCT #{distinct}"
          end
        end
        est = false
        begin 
          full_count = self.count(count_options)
          full_count = full_count.size if full_count.is_a?(Enumerable)
        rescue => e
          Rails.logger.error "[ERROR #{Time.now}] Batch tool count failed: #{e}"
          full_count = self.count
          est = true
        end
        (full_count / batch_size + 1).times do |batch|
          msg = "[INFO #{Time.now}] Working on #{self} batch " +
            "#{batch+1} of #{full_count / batch_size + 1} #{'est' if est} (batch size: #{batch_size})"
          # puts msg
          Rails.logger.info msg
          work_on_batch(batch, batch_size, options, &block)
        end
      end
      
      # Like do in batches put prints progress to stdout
      def script_do_in_batches(options = {}, &block)
        start = Time.now
        count_options = options.reject {|k,v| %w(order select).include?(k.to_s)}
        item_count = count(count_options)
        iteration = 1
        do_in_batches(options) do |record|
          msg = "#{iteration} of #{item_count} (#{(iteration.to_f / item_count * 100).round(2)}%)"
          puts "#{record.id.to_s.ljust(10)} #{msg.ljust(30)} time #{Time.now - start}"
          yield(record)
          iteration += 1
        end
        puts "Finished in #{Time.now - start} s"
      end
      
      private
      def work_on_batch(batch, batch_size, options = {}, &block)
        # pgsql is VERY weird about how it orders things by default, and by weird I mean inconsistent
        options[:order] = "#{table_name}.id ASC" if options[:order].blank?
        options.merge!(:offset => batch * batch_size, :limit => batch_size)
        all(options).each do |item|
          yield(item)
          item = nil
        end
        GC.start
      end
    end
  end
end
ActiveRecord::Base.send(:include, BatchTools::ActiveRecord)
