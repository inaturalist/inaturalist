# frozen_string_literal: true

FactoryBot.define do
  factory :taxon_description do
    title { Faker::Lorem.sentence }
    body { Faker::Lorem.paragraph }
    taxon
    url { "https://#{Faker::Internet.domain_name}" }
    locale { "en" }
  end
end
