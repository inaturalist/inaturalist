FactoryBot.define do
  factory :post do
    user
    parent { user }
    title { Faker::Lorem.sentence }
    body { Faker::Lorem.paragraph }
    published_at { Time.now }
  end
end
