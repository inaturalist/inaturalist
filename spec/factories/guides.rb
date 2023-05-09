FactoryBot.define do
  factory :guide do
    user
    title { Faker::Lorem.sentence }
  end
end
