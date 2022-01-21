FactoryBot.define do
  factory :flag do
    user
    flaggable_user
    flaggable { build :taxa }
    flag { Faker::Name.name }
    resolved { false }
  end
end
