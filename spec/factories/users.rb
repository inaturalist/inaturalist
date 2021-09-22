FactoryBot.define do
  factory :user do
    sequence(:login) { |n| "user#{n}" }
    email { Faker::Internet.email }
    name { Faker::Name.name }
    password { "monkey" }
    created_at { 5.days.ago.to_s(:db) }
    state { "active" }
    time_zone { "Pacific Time (US & Canada)" }

    factory :admin do
      roles { [association(:role, name: 'admin')] }
    end

    factory :curator do
      roles { [association(:role, name: 'curator')] }
    end
  end

  trait(:as_admin) { roles { [association(:role, name: 'admin')] } }
  trait(:as_curator) { roles { [association(:role, name: 'curator')] } }
end
