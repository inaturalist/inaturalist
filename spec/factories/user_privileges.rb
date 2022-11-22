FactoryBot.define do
  factory :user_privilege do
    user
    privilege { UserPrivilege::SPEECH }
  end
end
