class Update < ActiveRecord::Base

  include ActsAsElasticModel

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
      subscriber_id: subscriber_id,
      resource_id: resource_id,
      resource_type: resource_type,
      notifier_type: notifier_type,
      notifier_id: notifier_id,
      notification: notification,
      created_at: created_at,
      updated_at: updated_at,
      resource_owner_id: resource_owner_id,
      viewed_at: viewed_at
    }
  end

end
