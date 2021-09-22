FactoryBot.define do
  factory :observation_field do
    name { Faker::Lorem.sentence }
    datatype {'text'}
    user
  end
end
