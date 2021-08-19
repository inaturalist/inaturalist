FactoryBot.define do
  factory :observation do
    user
    taxon
    license { Observation::CC_BY }
    description { Faker::Lorem.sentence }
    uri { Faker::Internet.url }
    observed_on_string { 'yesterday at noon' }
  end
end
