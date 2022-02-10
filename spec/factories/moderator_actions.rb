# frozen_string_literal: true

FactoryBot.define do
  factory :moderator_action do
    user
    reason { Faker::Lorem.paragraph }
    action { ModeratorAction::HIDE }
    resource { build :comment }
  end
end
