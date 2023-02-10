class UpdateAction < ApplicationRecord

  include ActsAsElasticModel

  settings index: { number_of_shards: Rails.env.production? ? 6 : 4, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :created_at, type: "date"
      indexes :id, type: "integer"
      indexes :notification, type: "keyword"
      indexes :notifier, type: "keyword"
      indexes :notifier_id, type: "keyword"
      indexes :notifier_type, type: "keyword"
      indexes :resource_id, type: "keyword"
      indexes :resource_owner_id, type: "keyword"
      indexes :resource_type, type: "keyword"
      indexes :subscriber_ids, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :viewed_subscriber_ids, type: "keyword"
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
