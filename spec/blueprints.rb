require 'machinist/active_record'
# require 'sham'
require 'faker'

# Sham.name { Faker::Name.name }
# Sham.login { Faker::Internet.user_name.gsub(/\W/, '') }
# Sham.email { Faker::Internet.email }
# Sham.title { Faker::Lorem.sentence }
# Sham.body  { Faker::Lorem.paragraph }
# Sham.url { "http://#{Faker::Internet.domain_name}" }

CheckList.blueprint do
  place
end

Comment.blueprint do
  user
  body { Faker::Lorem.paragraph }
end

Friendship.blueprint do
  user
  friend
end

Identification.blueprint do
  user
  observation
  taxon
end

ListedTaxon.blueprint do
  list
  taxon
end

List.blueprint do
  user
  title { Faker::Lorem.sentence }
end

LifeList.blueprint do
  user
end

ListRule.blueprint do
  list
end

LocalPhoto.blueprint do
  user
end

Observation.blueprint do
  user { User.make! }
end

ObservationField.blueprint do
  name { Faker::Lorem.sentence }
  datatype {'text'}
  user
end

ObservationFieldValue.blueprint do
  observation
  observation_field
  value {"foo"}
end

ObservationPhoto.blueprint do
  observation
  photo
end

Photo.blueprint do
  user
  native_photo_id { rand(1000) }
end

Place.blueprint do
  name { Faker::Lorem.sentence }
  latitude { rand(90) }
  longitude { rand(180) }
end

Post.blueprint do
  user
  parent { user }
  title { Faker::Lorem.sentence }
  body { Faker::Lorem.paragraph }
  published_at { Time.now }
end

Post.blueprint(:draft) do
  published_at { nil }
end

Project.blueprint do
  user
  title { Faker::Lorem.sentence }
end

ProjectList.blueprint do
  project
end

ProjectUser.blueprint do
  user
  project
end

ProjectObservation.blueprint do
  observation
  project
end

QualityMetric.blueprint do
  user
  observation
  metric { QualityMetric::METRICS.first }
end

Role.blueprint do
  name { Faker::Lorem.sentence }
end

Role.blueprint(:admin) do
  name User::JEDI_MASTER_ROLE
end

Source.blueprint do
  title { Faker::Lorem.sentence }
end

Taxon.blueprint do
  name { Faker::Name.name }
  rank { Taxon::RANKS[rand(Taxon::RANKS.size)] }
end

Taxon.blueprint(:species) do
  rank {"species"}
end

Taxon.blueprint(:threatened) do
  conservation_status Taxon::IUCN_ENDANGERED
  is_active { true }
  rank {"species"}
end

TaxonLink.blueprint do
  user
  taxon
  url { "http://#{Faker::Internet.domain_name}" }
  site_title { Faker::Lorem.sentence }
end

TaxonPhoto.blueprint do
  taxon
  photo
end

TaxonName.blueprint do
  name { Faker::Name.name }
  taxon
end

TaxonRange.blueprint do
  taxon
  source
end

Update.blueprint do
  subscriber
  resource { Observation.make }
  notifier { Comment.make(:parent => self.resource) }
end

User.blueprint do
  login { Faker::Internet.user_name.gsub(/[W\.]/, '') }
  email { Faker::Internet.email }
  name { Faker::Name.name }
  password { "monkey" }
  created_at { 5.days.ago.to_s(:db) }
  state { "active" }
  time_zone { "Pacific Time (US & Canada)" }
end

