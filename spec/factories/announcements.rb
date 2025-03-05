# frozen_string_literal: true

FactoryBot.define do
  factory :announcement do
    start { 1.day.ago }
    send( :end ) { 1.day.from_now }
    body { Faker::Lorem.sentence }
    placement { "users/dashboard#sidebar" }
  end
end
