FactoryBot.define do
  factory :comment do
    user
    body { Faker::Lorem.paragraph }
    parent { create :observation }
  end
end
