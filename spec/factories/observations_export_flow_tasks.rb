# frozen_string_literal: true

FactoryBot.define do
  factory :observations_export_flow_task do
    user { create :user }
  end
end
