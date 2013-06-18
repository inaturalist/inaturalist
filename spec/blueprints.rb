require 'machinist/active_record'
# require 'sham'
require 'faker'

# Sham.name { Faker::Name.name }
# Sham.login { Faker::Internet.user_name.gsub(/\W/, '') }
# Sham.email { Faker::Internet.email }
# Sham.title { Faker::Lorem.sentence }
# Sham.body  { Faker::Lorem.paragraph }
# Sham.url { "http://#{Faker::Internet.domain_name}" }

Assessment.blueprint do
  taxon { Taxon.make! }
  user { User.make! }
  project { Project.make! }
end

AssessmentSection.blueprint do
  assessment { Assessment.make! }
  user { User.make! }
  title { Faker::Lorem.sentence }
  body { Faker::Lorem.paragraph }
end

CheckList.blueprint do
  place { Place.make! }
end

Comment.blueprint do
  user { User.make }
  body { Faker::Lorem.paragraph }
end

ConservationStatus.blueprint do
  user { User.make! }
  taxon { Taxon.make! }
  status { "E" }
  iucn { Taxon::IUCN_ENDANGERED }
  geoprivacy { Observation::OBSCURED }
end

Flag.blueprint do
  user { User.make! }
  flag { Faker::Name.name }
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

Message.blueprint do
  from_user { User.make! }
  to_user { User.make! }
  subject { Faker::Lorem.sentence }
  body { Faker::Lorem.paragraph }
end

OauthApplication.blueprint do
  name { Faker::Lorem.sentence }
  owner { User.make }
  url { "http://#{Faker::Internet.domain_name}" }
  redirect_uri { Doorkeeper.configuration.test_redirect_uri }
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
  observation { Observation.make! }
  observation_field { ObservationField.make! }
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

ProjectInvitation.blueprint do
  user { User.make! }
  project { Project.make! }
  observation { Observation.make! }
end

ProjectList.blueprint do
  project { Project.make }
end

ProjectObservationField.blueprint do
  project { Project.make }
  observation_field { ObservationField.make }
end

ProjectUser.blueprint do
  user { User.make }
  project { Project.make }
end

ProjectObservation.blueprint do
  observation { Observation.make }
  project { Project.make }
end

ProjectObservationRule.blueprint do
  ruler { Project.make }
  operator { "identified?" }
end

ProviderAuthorization.blueprint do
  user { User.make! }
  provider_name { 'flickr' }
  provider_uid { 'xxx@000' }
  token { 'foo' }
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

Sound.blueprint do
  user { User.make }
  native_sound_id { rand(1000) }
end

Source.blueprint do
  title { Faker::Lorem.sentence }
end

Subscription.blueprint do
  resource { Observation.make! }
  user { User.make! }
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

TaxonChange.blueprint do
  source { Source.make! }
  user { User.make! }
end

TaxonDrop.blueprint do
  source { Source.make! }
  user { User.make! }
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

TaxonMerge.blueprint do
  source { Source.make! }
  user { User.make! }
end

TaxonName.blueprint do
  name { Faker::Name.name }
  taxon { Taxon.make! }
end

TaxonRange.blueprint do
  taxon { Taxon.make! }
  source { Source.make }
end

TaxonScheme.blueprint do
  title { Faker::Lorem.sentence }
  source { Source.make! }
end

TaxonSplit.blueprint do
  source { Source.make! }
  user { User.make! }
end

TaxonStage.blueprint do
  source { Source.make! }
  user { User.make! }
end

TaxonSwap.blueprint do
  source { Source.make! }
  user { User.make! }
end

Update.blueprint do
  subscriber { User.make! }
  resource { Observation.make! }
  notifier { Comment.make!(:parent => self.resource) }
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
