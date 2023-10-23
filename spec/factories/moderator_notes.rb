# frozen_string_literal: true

FactoryBot.define do
  factory :moderator_note do
    user { build :user, :as_curator }
    subject_user { build :user }
    body { Faker::Lorem.paragraph }
  end
end
