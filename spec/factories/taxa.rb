FactoryBot.define do
  UN_TAXON_LIKE_NAME_BITS = /[^(A-z|\s|\-|×)]/
  factory :taxon do
    name { Faker::Name.first_name.gsub( UN_TAXON_LIKE_NAME_BITS, "" ) }
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
      name do
        case taxon_rank
        when "genushybrid"
          [
            Faker::Name.first_name.gsub( UN_TAXON_LIKE_NAME_BITS, "" ),
            "×",
            Faker::Name.first_name.gsub( UN_TAXON_LIKE_NAME_BITS, "" )
          ].join( " " )
        when "hybrid"
          [
            Faker::Name.first_name.gsub( UN_TAXON_LIKE_NAME_BITS, "" ),
            "Faker::Name.last_name.gsub( UN_TAXON_LIKE_NAME_BITS, "" ).downcase",
            "×",
            "Faker::Name.last_name.gsub( UN_TAXON_LIKE_NAME_BITS, "" ).downcase"
          ].join( " " )
        when "species"
          [
            Faker::Name.first_name.gsub( UN_TAXON_LIKE_NAME_BITS, "" ),
            Faker::Name.last_name.gsub( UN_TAXON_LIKE_NAME_BITS, "" ).downcase
          ].join( " " )
        when Taxon::RANK_LEVELS[taxon_rank] < Taxon::SPECIES_LEVEL
          [
            Faker::Name.first_name.gsub( UN_TAXON_LIKE_NAME_BITS, "" ),
            Faker::Name.last_name.gsub( UN_TAXON_LIKE_NAME_BITS, "" ).downcase,
            Faker::Name.last_name.gsub( UN_TAXON_LIKE_NAME_BITS, "" ).downcase
          ].join( " " )
        else Faker::Name.first_name.gsub( UN_TAXON_LIKE_NAME_BITS, "" )
        end
      end
      rank { taxon_rank }
    end
  end
end
