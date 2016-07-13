class Update < ActiveRecord::Base

  belongs_to :subscriber, :class_name => "User"
  belongs_to :resource, :polymorphic => true
  belongs_to :notifier, :polymorphic => true
  belongs_to :resource_owner, :class_name => "User"


  # non-mentions: [ notifier_id, notifier_type, subscriber_id, notification ]
  validates_uniqueness_of :notifier_id, unless: -> { notification == "mention" },
    scope: [:notifier_type, :subscriber_id, :notification]
  # comment/ID mentions: [ notifier_id, notifier_type, subscriber_id ]
  validates_uniqueness_of :notifier_id, if: -> { notification == "mention" &&
    ![ "Observation", "Post" ].include?(notifier_type) },
    scope: [:notifier_type, :subscriber_id]
  # obs/post mentions: [ notifier_id, notifier_type, subscriber_id, resource_type, resource_id ]
  validates_uniqueness_of :notifier_id, if: -> { notification == "mention" &&
    [ "Observation", "Post" ].include?(notifier_type) },
    scope: [:notifier_type, :subscriber_id, :resource_type, :resource_id ]
  validates_presence_of :resource, :notifier, :subscriber
  
  before_create :set_resource_owner
  
  # NOTIFICATIONS = %w(create change activity)
  YOUR_OBSERVATIONS_ADDED = "your_observations_added"
  
  # scope :unviewed, -> { where("viewed_at IS NULL") }
  # scope :activity, -> { where(notification: "activity") }
  # scope :mention, -> { where(notification: "mention") }

  attr_accessor :skip_indexing

  def to_s
    "<Update #{id} subscriber: #{subscriber_id} resource_type: #{resource_type} " +
      "resource_id: #{resource_id} notifier_type: #{notifier_type} notifier_id: #{notifier_id}>"
  end

  def self.migrate_to_new_tables
    past_two_months_ago = false
    batch_size = 20000
    first = Update.first.id
    last = Update.last.id
    puts "First: #{first}, Last: #{last}"
    start_time = Time.now
    time = Benchmark.measure do
      Update.joins(:subscriber).
             where("users.last_active IS NOT NULL").
             find_in_batches(batch_size: batch_size) do |batch|
        if !past_two_months_ago && batch.first.created_at >= 2.months.ago
          past_two_months_ago = true
        end
        puts "ID: #{batch.first.id}, Time: #{Time.now - start_time}"
        action_ids = { }
        subscriptions = [ ]
        Update.connection.transaction do
          batch.each do |u|
            next if !past_two_months_ago && !u.viewed_at
            action_attrs = {
              resource_id: u.resource_id,
              resource_type: u.resource_type,
              notifier_type: u.notifier_type,
              notifier_id: u.notifier_id,
              notification: u.notification,
              resource_owner_id: u.resource_owner_id
            }
            key = action_attrs.flatten.join(",")
            action_id = action_ids[key]
            # this action hasn't been cached this batch
            if !action_id
              action = UpdateAction.first_with_attributes(action_attrs,
                skip_indexing: true, skip_validations: true, created_at: u.created_at)
              next if !action
              action_id = action.id
            end
            action_ids[key] = action_id
            subscriptions <<  {
              update_action_id: action_id,
              subscriber_id: u.subscriber_id,
              viewed_at: u.viewed_at ? "'#{u.viewed_at}'" : "NULL"
            }
          end
        end
        next if subscriptions.empty?
        values = subscriptions.map{ |s| "(#{ s.values.join(",") })" }
        sql = "INSERT INTO update_subscribers (update_action_id, subscriber_id, viewed_at) " +
              "VALUES #{ values.join(",") }"
        puts "inserting"
        Update.connection.execute(sql)
        puts "inserted"
      end
    end
    pp time
  end

end
