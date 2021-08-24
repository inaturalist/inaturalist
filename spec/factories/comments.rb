FactoryBot.define do
  factory :comment do
    user
    body { Faker::Lorem.paragraph }
    parent { build :observation }
  end
end
