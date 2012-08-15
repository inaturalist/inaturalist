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
  place { Place.make! }
end

Comment.blueprint do
  user { User.make }
  body { Faker::Lorem.paragraph }
end

FlickrIdentity.blueprint do
  user { User.make! }
end

Friendship.blueprint do
  user { User.make }
  friend { User.make }
end

Identification.blueprint do
  user { User.make }
  observation { Observation.make }
  taxon { Taxon.make! }
end

ListedTaxon.blueprint do
  list { List.make! }
  taxon { Taxon.make! }
end

List.blueprint do
  user { User.make! }
  title { Faker::Lorem.sentence }
end

LifeList.blueprint do
  user { User.make! }
end

ListRule.blueprint do
  list { List.make! }
end

LocalPhoto.blueprint do
  user { User.make }
end

Observation.blueprint do
  user { User.make! }
end

ObservationField.blueprint do
  name { Faker::Lorem.sentence }
  datatype {'text'}
  user { User.make }
end

ObservationFieldValue.blueprint do
  observation { Observation.make }
  observation_field { ObservationField.make }
  value {"foo"}
end

ObservationPhoto.blueprint do
  observation { Observation.make }
  photo { Photo.make }
end

Photo.blueprint do
  user { User.make }
  native_photo_id { rand(1000) }
end

Place.blueprint do
  name { Faker::Lorem.sentence }
  latitude { rand(90) }
  longitude { rand(180) }
end

Post.blueprint do
  user { User.make! }
  parent { self.user }
  title { Faker::Lorem.sentence }
  body { Faker::Lorem.paragraph }
  published_at { Time.now }
end

Post.blueprint(:draft) do
  published_at { nil }
end

Project.blueprint do
  user { User.make }
  title { Faker::Lorem.sentence }
end

ProjectList.blueprint do
  project { Project.make }
end

ProjectUser.blueprint do
  user { User.make }
  project { Project.make }
end

ProjectObservation.blueprint do
  observation { Observation.make }
  project { Project.make }
end

QualityMetric.blueprint do
  user { User.make }
  observation { Observation.make }
  metric { QualityMetric::METRICS.first }
end

Role.blueprint do
  name { Faker::Lorem.sentence }
end

Role.blueprint(:admin) do
  name { User::JEDI_MASTER_ROLE }
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
  conservation_status {Taxon::IUCN_ENDANGERED}
  rank {"species"}
  is_active { true }
end

TaxonLink.blueprint do
  user { User.make! }
  taxon { Taxon.make! }
  url { "http://#{Faker::Internet.domain_name}" }
  site_title { Faker::Lorem.sentence }
end

TaxonPhoto.blueprint do
  taxon { Taxon.make! }
  photo { Photo.make }
end

TaxonName.blueprint do
  name { Faker::Name.name }
  taxon { Taxon.make! }
end

TaxonRange.blueprint do
  taxon { Taxon.make! }
  source { Source.make }
end

Update.blueprint do
  subscriber { User.make }
  resource { Observation.make }
  notifier { Comment.make(:parent => self.resource) }
end

User.blueprint do
  login { 
    s = Faker::Internet.user_name.gsub(/[W\.]/, '')
    s = User.suggest_login(s) if s.size < User::MIN_LOGIN_SIZE || User.where(:login => s).exists?
    s
  }
  email { Faker::Internet.email }
  name { Faker::Name.name }
  password { "monkey" }
  created_at { 5.days.ago.to_s(:db) }
  state { "active" }
  time_zone { "Pacific Time (US & Canada)" }
end

