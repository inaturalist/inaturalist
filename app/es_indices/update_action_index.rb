class UpdateAction < ActiveRecord::Base

  include ActsAsElasticModel

  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :id, type: "long"
      indexes :resource_type, type: "keyword"
      indexes :notifier, type: "keyword"
      indexes :notification, type: "keyword"
      indexes :notifier_type, type: "keyword"
    end
  end

  def as_indexed_json(options={})
    raise "UpdateAction being indexed improperly" unless created_but_not_indexed || Rails.env.test?
    {
      id: id,
      subscriber_ids: filtered_subscriber_ids || [],
      viewed_subscriber_ids: [],
      resource_id: resource_id,
      resource_type: resource_type,
      notifier_type: notifier_type,
      notifier_id: notifier_id,
      notification: notification,
      created_at: created_at,
      resource_owner_id: resource_owner_id
    }
  end

end
