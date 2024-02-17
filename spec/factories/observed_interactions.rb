# frozen_string_literal: true

FactoryBot.define do
  factory :observed_interaction do
    user
    subject_observation { create :observation }
    object_observation { create :observation }
    annotations { [make_annotation] }
  end
end
