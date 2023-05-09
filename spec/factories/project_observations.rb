FactoryBot.define do
  factory :project_observation do
    observation
    project
    user { observation.user }
  end
end
