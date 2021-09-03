FactoryBot.define do
  factory :project_observation_rule do
    ruler { build :project }
    operator { 'identified?' }
  end
end
