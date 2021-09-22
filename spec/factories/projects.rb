FactoryBot.define do
  factory :project do
    user { association(:user_privilege, privilege: UserPrivilege::ORGANIZER).user }
    title { Faker::Lorem.sentence }
    description { Faker::Lorem.paragraph.truncate(255) }
  end
end
