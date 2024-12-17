FactoryBot.define do
  factory :identification do
    user { association( :user_privilege, privilege: UserPrivilege::INTERACTION ).user }
    observation
    taxon
  end
end
