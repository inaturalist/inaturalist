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
          after_create :create_activity_update
          after_destroy :destroy_or_shift_activity_streams
          
          # Manually skip updates for this record by setting @skip_update
          attr_accessor :skip_update
          
          write_inheritable_attribute :activity_stream_options, options
          class_inheritable_reader :activity_stream_options
        end
      end
      
      module SingletonMethods
        def create_activity_update
          return if @skip_update
          return unless self.respond_to?(:user) && self.user
          
          # Handle batch updates
          batch_point = if activity_stream_options[:batch_window]
            Time.now - activity_stream_options[:batch_window]
          else
            nil
          end
          if batch_point && 
              existing_stream = ActivityStream.last(:conditions => [
                "activity_object_type = ? AND user_id = ? AND created_at >= ?", 
                self.class.to_s, user, batch_point])
            
            existing_records = if activity_stream_options[:user_scope]
              self.class.
                send(activity_stream_options[:user_scope], existing_stream.user).
                all(:conditions => ["#{self.class.table_name}.created_at >= ?", batch_point])
            elsif self.class.column_names.include?("user_id")
              self.class.all(:conditions => [
                "user_id = ? AND created_at >= ?", user, batch_point
              ])
            else
              raise "Models with activity streams must belong to a user or specificy a user_scope."
            end
            
            ActivityStream.update_all(
              ["batch_ids = ?, updated_at = ?", existing_records.map(&:id).join(','), Time.now], 
              ["activity_object_type = ? AND activity_object_id = ?", 
                existing_stream.activity_object_type, existing_stream.activity_object_id]
            )
            
          # Handle single updates
          else
            self.user.followers.each do |follower|
              ActivityStream.create(
                :user_id => self.user_id,
                :subscriber_id => follower.id,
                :activity_object => self
              )
            end
          end
          true
        end
        
        # Destroy associated activity objects OR if they are batch updates, 
        # shift them to another observation in the batch
        def destroy_or_shift_activity_streams
          unless as = activity_streams.first
            return true
          end
          if as.batch_ids.blank?
            ActivityStream.delete_all(["activity_object_id = ?", self])
          else
            batch = self.class.all(:conditions => ["id IN (?)", as.batch_ids.split(',')], :limit => 200)
            if batch.blank?
              ActivityStream.delete_all(["activity_object_id = ?", self])
            else
              ActivityStream.update_all(
                ["activity_object_id = ?", batch.first.id], 
                ["activity_object_id = ?", self]
              )
            end
          end
          true
        end
      end
    end
  end
end
