FactoryBot.define do
  factory :taxon_name do
    taxon
    name { Faker::Name.name.gsub( /[^(A-z|\s|\-|×)]/, "" ) }
    is_valid { true }
  end
end
