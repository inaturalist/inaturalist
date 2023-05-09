FactoryBot.define do
  factory :guide_taxon do
    guide
    taxon
    name { Faker::Lorem.sentence }
    display_name { Faker::Lorem.sentence }
  end
end
