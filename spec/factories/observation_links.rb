# frozen_string_literal: true

FactoryBot.define do
  factory :observation_link do
    observation
    href { Faker::Internet.url }
  end
end
