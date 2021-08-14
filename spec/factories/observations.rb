FactoryBot.define do
  factory :observation do
    user
    license { Observation::CC_BY }
    description { Faker::Lorem.sentence }
  end
end
