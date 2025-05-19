# frozen_string_literal: true

FactoryBot.define do
  factory :project_fave do
    project
    user
  end
end
