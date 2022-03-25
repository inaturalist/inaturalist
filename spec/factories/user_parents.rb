# frozen_string_literal: true

FactoryBot.define do
  factory :user_parent do
    user { build :user, birthday: 5.years.ago.to_date.to_s }
    parent_user { build :user }
    name { Faker::Name.name }
    child_name { Faker::Name.name }
    email { Faker::Internet.email }

    trait :as_donor do
      donorbox_donor_id { Faker::Number.number }
    end
  end
end
