# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence( :login ) {| n | "user#{n}" }
    email { Faker::Internet.email }
    name { Faker::Name.name }
    password { "monkey" }
    created_at { 5.days.ago.to_s( :db ) }
    state { "active" }
    time_zone { "Pacific Time (US & Canada)" }
    confirmed_at { 4.days.ago.to_s( :db ) }
    confirmation_token { Faker::Alphanumeric.alphanumeric }

    factory :admin do
      roles { [association( :role, name: "admin" )] }
    end

    factory :curator do
      roles { [association( :role, name: "curator" )] }
    end
  end

  trait( :as_admin ) { roles { [association( :role, name: "admin" )] } }
  trait( :as_curator ) { roles { [association( :role, name: "curator" )] } }
  trait( :as_unconfirmed ) do
    confirmed_at { nil }
    confirmation_token { nil }
  end
end
