# frozen_string_literal: true

FactoryBot.define do
  factory :update_action do
    resource { create :observation }
    notifier { create :comment, parent: resource }
    notification { "activity" }
  end
end
