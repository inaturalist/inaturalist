# frozen_string_literal: true

FactoryBot.define do
  factory :oauth_application do
    name { Faker::Name.name }
    redirect_uri { Faker::Internet.url }
    owner { build :user }
  end
end
