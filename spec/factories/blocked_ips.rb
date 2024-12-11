FactoryBot.define do
  factory :blocked_ip do
    ip { Faker::Internet.ip_v4_address }
    user
  end
end
