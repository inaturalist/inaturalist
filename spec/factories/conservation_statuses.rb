FactoryBot.define do
  factory :conservation_status do
    user
    taxon { build :taxon, :as_species }
    status { "E" }
    iucn { Taxon::IUCN_ENDANGERED }
  end
end
