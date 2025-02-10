# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    user
    to_user { create :user }
    from_user { user }
    subject { Faker::Lorem.sentence }
    body { Faker::Lorem.paragraph }
  end
end
