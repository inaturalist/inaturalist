class UpdateActionToNotificationConverter

  BATCH_SIZE = 1000
  LOOKAHEAD_RANGE = 1000000
  SQL_BATCH_SIZE = 1000

  attr_accessor :notifier_attrs, :start_time,
    :start_id, :end_id, :total_processed, :notification_attrs, :notifications_notifier_attrs

  def self.truncate
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE notifications RESTART IDENTITY")
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE notifiers RESTART IDENTITY")
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE notifications_notifiers RESTART IDENTITY")
  end

  def self.set_nn_categories
    NotificationsNotifier.includes(:notification, :notifier).find_in_batches( batch_size: 5000 ) do |batch|
      Notification.transaction do
        puts "SetNNCategories: #{batch.first.id}"
        batch.each do |nn|
          nn.update_columns( category: nn.set_category )
        end
      end
    end
  end

  def self.set_notification_categories
    Notification.includes( { notifications_notifiers: :notifier } ).find_in_batches( batch_size: 5000 ) do |batch|
      Notification.transaction do
        puts "SetCategories: #{batch.first.id}"
        batch.each do |notification|
          notification.set_category
        end
      end
    end
  end

  def start
    self.notifier_attrs = []
    self.notification_attrs = []
    self.notifications_notifier_attrs = []
    self.total_processed = 0
    self.start_time = Time.now
    self.start_id = UpdateAction.minimum(:id) - 1
    self.end_id = UpdateAction.maximum(:id)
    NotificationsNotifier.skip_callback(:save, :after, :set_notification_category)
    self.loop( "each_result_initial" )

    self.total_processed = 0
    self.start_time = Time.now
    self.start_id = UpdateAction.minimum(:id) - 1
    self.loop( "each_result_secondary" )
    UpdateActionToNotificationConverter.set_nn_categories
    UpdateActionToNotificationConverter.set_notification_categories
  end

  def batch_insert_notifiers( options = { } )
    return if self.notifier_attrs.empty?
    return if !options[:finish] && self.notifier_attrs.length < UpdateActionToNotificationConverter::SQL_BATCH_SIZE
    Notifier.connection.execute(
      "INSERT INTO notifiers ( resource_type, resource_id, action_date ) VALUES #{
      self.notifier_attrs.map{ |n| "('#{n[:resource_type]}',#{n[:resource_id]},'#{n[:action_date]
        .strftime("%Y-%m-%d %H:%M:%S.%N")}')" }.join( "," )
    } ON CONFLICT DO NOTHING")
    self.notifier_attrs = []
  end

  def batch_insert_notifications( options = { } )
    return if self.notification_attrs.empty?
    return if !options[:finish] && self.notification_attrs.length < UpdateActionToNotificationConverter::SQL_BATCH_SIZE
    Notifier.connection.execute(
      "INSERT INTO notifications ( resource_type, resource_id, user_id ) VALUES #{
      self.notification_attrs.map{ |n| "('#{n[:resource_type]}',#{n[:resource_id]},#{n[:user_id]})" }.join( "," )
    } ON CONFLICT DO NOTHING")
    self.notification_attrs = []
  end

  def batch_insert_notifications_notifiers( options = { } )
    return if self.notifications_notifier_attrs.empty?
    return if !options[:finish] && self.notifications_notifier_attrs.length < UpdateActionToNotificationConverter::SQL_BATCH_SIZE
    Notifier.connection.execute(
      "INSERT INTO notifications_notifiers ( notification_id, notifier_id, reason, viewed_at, read_at ) VALUES #{
      self.notifications_notifier_attrs.map{ |n|
        date = n[:viewed] ? "'#{self.start_time.strftime("%Y-%m-%d %H:%M:%S.%N")}'" : "null"
        "(#{n[:notification_id]},#{n[:notifier_id]},'#{n[:reason]}',#{date},#{date})"
      }.join( "," )
    } ON CONFLICT DO NOTHING")
    self.notifications_notifier_attrs = []
  end

  def each_result_initial( result, ar_record )
    self.notifier_attrs << {
      resource_type: ar_record.notifier_type,
      resource_id: ar_record.notifier_id,
      action_date: ar_record.created_at
    }
    result.subscriber_ids.compact.each do |subscriber_id|
      self.notification_attrs << {
        resource_type: ar_record.resource_type,
        resource_id: ar_record.resource_id,
        user_id: subscriber_id
      }
    end
  end

  def each_result_secondary( result, ar_record )
    viewed_subscriber_ids = Hash[result.viewed_subscriber_ids.zip(result.viewed_subscriber_ids)]
    notifier = Notifier.find_or_create_by(
      resource: ar_record.notifier,
      action_date: ar_record.created_at
    )
    result.subscriber_ids.compact.each do |subscriber_id|
      next if subscriber_id.blank?
      viewed = viewed_subscriber_ids[subscriber_id]
      notification = Notification.find_or_create_by(
        user_id: subscriber_id,
        resource: ar_record.resource
      )
      self.notifications_notifier_attrs << {
        notifier_id: notifier.id,
        notification_id: notification.id,
        reason: ar_record.notification,
        viewed: viewed
      }
    end
  end

  def debug_timing( start_id, results )
    total_time = (Time.now - self.start_time).round(2)
    puts "Total: #{self.total_processed}, Time: #{total_time}, Avg: #{(self.total_processed/total_time).round(2)}"
    return results.length > 0 ?
      [results.last.id.to_i, start_id + UpdateActionToNotificationConverter::LOOKAHEAD_RANGE].min :
      start_id + UpdateActionToNotificationConverter::LOOKAHEAD_RANGE
  end

  def loop( method )
    start_id = self.start_id
    while start_id
      puts start_id
      results = UpdateAction.elastic_search(
        filters:[
          { range: { id: { gt: start_id, lte: start_id + UpdateActionToNotificationConverter::LOOKAHEAD_RANGE } } },
          { bool: {
            should: [
              { terms: { notifier_type: ["Comment", "ActsAsVotable::Vote", "ObservationFieldValue", "Post"] } },
              { term: { notification: "mention" } }
            ]
          } }
        ],
        size: UpdateActionToNotificationConverter::BATCH_SIZE,
        sort: { id: :asc }
      ).to_a
      if results.empty?
        start_id = self.debug_timing( start_id, results )
        break if start_id >= self.end_id
        next
      end
      ar_records = UpdateAction.where(id: results.map(&:id)).includes( :resource, :notifier )
      ar_records_hash = Hash[ar_records.map{ |r| [r.id, r] }]
      if ar_records_hash.length > 0
        Notification.transaction do
          results.each do |r|
            ar_record = ar_records_hash[r.id.to_i]
            next unless ar_record
            if ( ar_record.resource_type === "User" && ar_record.notifier_type === "Post" )
              ar_record.resource = ar_record.notifier
            end
            self.send( method, r, ar_record )
          end
        end
        batch_insert_notifiers( )
        batch_insert_notifications( )
        batch_insert_notifications_notifiers( )
      end
      batch_insert_notifiers( finish: true )
      batch_insert_notifications( finish: true )
      batch_insert_notifications_notifiers( finish: true )
      self.total_processed += ar_records_hash.length
      start_id = self.debug_timing( start_id, results )
      # break if total_processed > 100000
      break if start_id >= self.end_id
    end
  end
end
