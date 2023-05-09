FactoryBot.define do
  factory :observation_field_value do
    observation
    observation_field
    value { 'foo' }
    user { observation.user }
  end
end
