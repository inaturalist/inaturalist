FactoryBot.define do
  factory :flag do
    user
    flaggable { build :taxon }
    flag { Faker::Name.name }
    resolved { false }
  end
end
