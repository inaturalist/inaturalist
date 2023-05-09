FactoryBot.define do
  factory :taxon_link do
    site_title { Faker::Lorem.sentence }
    taxon
    url { "https://#{Faker::Internet.domain_name}" }
    user
  end
end
