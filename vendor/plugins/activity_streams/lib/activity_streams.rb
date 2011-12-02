# ActivityStreams
module ActivityStreams
  module Acts #:nodoc:
    module ActivityStreamable #:nodoc:
      
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_activity_streamable(options = {})
          return if self.included_modules.include?(ActivityStreams::Acts::ActivityStreamable::SingletonMethods)
          include ActivityStreams::Acts::ActivityStreamable::SingletonMethods
          
          has_many :activity_streams, :as => :activity_object
          after_create :create_activity_update_after_create
          after_destroy :destroy_or_shift_activity_streams
          
          # Manually skip updates for this record by setting @skip_update
          attr_accessor :skip_update
          
          write_inheritable_attribute :activity_stream_options, options
          class_inheritable_reader :activity_stream_options
        end
        
        def create_activity_update(id)
          Rails.logger.debug "[DEBUG] creating act up for #{id}"
          activity_object = id.is_a?(self) ? id : find_by_id(id)
          return unless activity_object
          
          Rails.logger.debug "[DEBUG] proceeding with #{id}"
          
          # Handle batch updates
          batch_point = if activity_stream_options[:batch_window]
            Time.now - activity_stream_options[:batch_window]
          else
            nil
          end
          if batch_point && 
              existing_stream = ActivityStream.last(:conditions => [
                "activity_object_type = ? AND user_id = ? AND created_at >= ?", 
                self.to_s, activity_object.user, batch_point])
            
            Rails.logger.debug "[DEBUG] updating batches"
            
            existing_records = if activity_stream_options[:user_scope]
              send(activity_stream_options[:user_scope], existing_stream.user).
              all(:conditions => ["#{table_name}.created_at >= ?", batch_point])
            elsif column_names.include?("user_id")
              all(:conditions => [
                "user_id = ? AND created_at >= ?", activity_object.user, batch_point
              ])
            else
              raise "Models with activity streams must belong to a user or specificy a user_scope."
            end
            
            batch_ids = existing_records.map{|r| r.id}.sort.reverse
            col_size_limit = ActivityStream.columns.detect{|c| c.name == 'batch_ids'}.limit
            while batch_ids.join(',').size > col_size_limit
              batch_ids.pop
            end
            
            ActivityStream.update_all(
              ["batch_ids = ?, updated_at = ?", batch_ids.join(','), Time.now], 
              ["activity_object_type = ? AND activity_object_id = ?", 
                existing_stream.activity_object_type, existing_stream.activity_object_id]
            )
            
          # Handle single updates
          else
            Rails.logger.debug "[DEBUG] creating singletons, activity_object.user.followers.size: #{activity_object.user.followers.size}"
            activity_object.user.followers.find_each do |follower|
              ActivityStream.create!(
                :user_id => activity_object.user_id,
                :subscriber_id => follower.id,
                :activity_object => activity_object
              )
            end
            
            # clear out old activity streams
            ActivityStream.delete_all(["user_id = ? AND created_at < ?", activity_object.user, 1.year.ago])
          end
          true
        end
      end
      
      module SingletonMethods
        def create_activity_update_after_create
          return true if @skip_update
          return true unless self.respond_to?(:user) && self.user
          
          if Object.const_get('Delayed')
            self.class.send_later(:create_activity_update, id, :dj_priority => 1)
          else
            self.class.create_activity_update(self)
          end
          true
        end
        
        # Destroy associated activity objects OR if they are batch updates, 
        # shift them to another observation in the batch
        def destroy_or_shift_activity_streams
          unless as = activity_streams.first
            return true
          end
          
          # Destroy single AS's with single activity objects
          if as.batch_ids.blank?
            ActivityStream.delete_all([
              "activity_object_type = ? AND activity_object_id = ?", 
              self.class.to_s, self
            ])
            return true
          end
          
          
          batch = self.class.all(:conditions => ["id IN (?)", as.batch_ids.split(',')], :limit => 200)
          
          # Nothing left in the batch, destroy them all
          if batch.blank?
            ActivityStream.delete_all([
              "activity_object_type = ? AND activity_object_id = ?", 
              self.class.to_s, self
            ])
            return true
          end
          
          # Update activity streams so their act. obj. is the next in the batch
          ActivityStream.update_all(
            ["activity_object_id = ?", batch.first.id], 
            ["activity_object_type = ? AND activity_object_id = ?", self.class.to_s, self]
          )
          true
        end
        
      end
    end
  end
end
