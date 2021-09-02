FactoryBot.define do
  factory :taxon do
    name { Faker::Name.name.gsub( /[^(A-z|\s|\-|×)]/, "" ) }
    rank { Taxon::RANKS.sample }
    is_active { true }
  end

  trait :with_taxon_names do
    transient { name_count { 1 } }
    after :build do |taxon, eval|
      build_list :taxon_name, eval.name_count, taxon: taxon
    end
  end

  trait :threatened do
    after :build do |taxon|
      taxon.conservation_statuses = [build(:conservation_status, taxon: taxon)]
    end
  end

  Taxon::RANKS.each do |taxon_rank|
    trait :"as_#{taxon_rank}" do
      rank { taxon_rank }
    end
  end
end
