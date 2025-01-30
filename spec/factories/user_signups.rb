# frozen_string_literal: true

FactoryBot.define do
  factory :user_signup do
    user
    ip { Faker::Internet.ip_v4_address }
    vpn { false }
    browser_id { Faker::Alphanumeric.alphanumeric }
    incognito { false }
  end
end
