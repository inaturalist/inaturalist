# frozen_string_literal: true

FactoryBot.define do
  factory :site do
    name { Faker::Lorem.sentence }
    url { Faker::Internet.url }
  end
end
