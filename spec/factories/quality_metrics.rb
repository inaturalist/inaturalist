FactoryBot.define do
  factory :quality_metric do
    user
    observation
    metric { QualityMetric::METRICS.first }
  end
end
