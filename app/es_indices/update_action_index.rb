class UpdateAction < ActiveRecord::Base

  include ActsAsElasticModel

  scope :load_for_index, -> { includes(:update_subscribers) }

  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :id, type: "long"
      indexes :resource_type, analyzer: "keyword_analyzer"
      indexes :notifier, analyzer: "keyword_analyzer"
      indexes :notification, analyzer: "keyword_analyzer"
    end
  end

  def as_indexed_json(options={})
    {
      id: id,
      subscriber_ids: update_subscribers.map(&:subscriber_id).uniq.sort,
      resource_id: resource_id,
      resource_type: resource_type,
      notifier_type: notifier_type,
      notifier_id: notifier_id,
      notification: notification,
      created_at: created_at,
      resource_owner_id: resource_owner_id,
      viewed_subscriber_ids: (update_subscribers.loaded? ?
        update_subscribers.select{ |s| !s.viewed_at.nil? }.map(&:subscriber_id) :
        update_subscribers.where("viewed_at IS NOT NULL").map(&:subscriber_id)).uniq.sort,
    }
  end

end
