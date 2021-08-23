FactoryBot.define do
  factory :observation do
    user
    taxon
    license { Observation::CC_BY }
    description { Faker::Lorem.sentence }
    uri { Faker::Internet.url }
    observed_on_string { 'yesterday at noon' }
    observed_on { Date.yesterday }
    time_observed_at { Date.yesterday.noon }
    time_zone { 'UTC' }
    zic_time_zone { 'UTC' }
  end

  trait :without_times do
    observed_on { nil }
    observed_on_string { nil }
    time_observed_at { nil }
    time_zone { nil }
    zic_time_zone { nil }
  end

  trait :research_grade do
    taxon { build :taxon, :as_species }
    latitude { 1 }
    longitude { 1 }
    quality_grade { Observation::RESEARCH_GRADE }
    identifications { [association(:identification)] }
  end

  trait :with_sounds do
    transient { count { 1 } }
    observation_sounds { Array.new(count) { association(:observation_sound) } }
  end

  trait :with_photos do
    transient { count { 1 } }
    observation_photos { Array.new(count) { association(:observation_photo) } }
  end
end
