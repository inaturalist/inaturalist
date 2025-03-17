FactoryBot.define do
  factory :comment do
    user { association( :user_privilege, privilege: UserPrivilege::INTERACTION ).user }
    body { Faker::Lorem.paragraph }
    parent { create :observation }
  end
end
