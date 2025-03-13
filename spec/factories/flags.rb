FactoryBot.define do
  factory :flag do
    user { association( :user_privilege, privilege: UserPrivilege::INTERACTION ).user }
    flaggable_user { }
    flaggable { build :taxon }
    flag { Faker::Name.name }
    resolved { false }
  end
end
