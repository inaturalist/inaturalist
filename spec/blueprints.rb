require 'machinist/active_record'
require 'faker'

Announcement.blueprint do
  start { 1.day.ago }
  send(:end) { 1.day.from_now }
  body { Faker::Lorem.sentence }
  placement { "users/dashboard#sidebar" }
end
Annotation.blueprint do
  controlled_attribute { ControlledTerm.make! }
  controlled_value { ControlledTerm.make! }
  resource { Observation.make! }
end

ApiEndpoint.blueprint do
  title { Faker::Lorem.sentence }
end

ApiEndpointCache.blueprint do
  api_endpoint { ApiEndpoint.make! }
end

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

Atlas.blueprint do
  taxon { Taxon.make }
  user { User.make }
  is_active { true }
end

CheckList.blueprint do
  place { make_place_with_geom }
end

Color.blueprint do
  value { %w(red green blue)[rand(3)] }  
end

Comment.blueprint do
  user { User.make }
  body { Faker::Lorem.paragraph }
  parent { Observation.make! }
end

CompleteSet.blueprint do
  taxon { Taxon.make! }
  place { make_place_with_geom }
  user { User.make! }
  is_active { true }
end

ConservationStatus.blueprint do
  user { User.make! }
  taxon { Taxon.make! }
  status { "E" }
  iucn { Taxon::IUCN_ENDANGERED }
end

ControlledTerm.blueprint do
end

ControlledTermLabel.blueprint do
  label { Faker::Lorem.word }
  definition { Faker::Lorem.paragraph }
end

ControlledTermTaxon.blueprint do
  controlled_term { ControlledTerm.make! }
  taxon { Taxon.make! }
end

ControlledTermValue.blueprint do
  controlled_attribute { ControlledTerm.make! }
  controlled_value { ControlledTerm.make!(is_value: true) }
end

DataPartner.blueprint do
  name { Faker::Lorem.sentence }
  description { Faker::Lorem.sentence }
  url { "https://#{Faker::Internet.domain_name}" }
end

ExplodedAtlasPlace.blueprint do
  atlas { Atlas.make! }
  place { make_place_with_geom }
end

FileExtension.blueprint do
  extension { "jpg" }
end

FilePrefix.blueprint do
  prefix { "http://staticdev.inaturalist.org/photos/" }
end

Flag.blueprint do
  user { User.make! }
  flaggable_user { User.make! }
  flaggable { Taxon.make! }
  flag { Faker::Name.name }
  resolved { false }
end

FlickrIdentity.blueprint do
  user { User.make! }
end

Friendship.blueprint do
  user { User.make! }
  friend { User.make! }
end

GoogleStreetViewPhoto.blueprint do
  user { User.make! }
  native_photo_id { "http://maps.googleapis.com/maps/api/streetview?location=-0.742447,-90.303923&heading=29.78017781376499&pitch=8.134364432152863&fov=45&sensor=false" }
end

Guide.blueprint do
  user { User.make! }
  title { Faker::Lorem.sentence }
end

GuidePhoto.blueprint do
  guide_taxon { GuideTaxon.make! }
  photo { Photo.make! }
  description { Faker::Lorem.paragraph.truncate(255) }
end

GuideRange.blueprint do
  guide_taxon { GuideTaxon.make! }
  rights_holder { Faker::Name.name }
  thumb_url { "http://#{Faker::Internet.domain_name}/thumb.png" }
  medium_url { "http://#{Faker::Internet.domain_name}/medium.png" }
  original_url { "http://#{Faker::Internet.domain_name}/original.png" }
end

GuideSection.blueprint do
  guide_taxon { GuideTaxon.make! }
  title { Faker::Lorem.sentence }
  description { Faker::Lorem.paragraph }
end

GuideTaxon.blueprint do
  guide { Guide.make! }
  taxon { Taxon.make! }
  name { Faker::Lorem.sentence }
  display_name { Faker::Lorem.sentence }
end

GuideUser.blueprint do
  guide { Guide.make! }
  user { User.make! }
end

Identification.blueprint do
  user { User.make! }
  observation { Observation.make! }
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

ListRule.blueprint do
  list { List.make! }
end

LocalPhoto.blueprint do
  user { User.make }
  file_content_type { "image/jpeg" }
  file_file_name    { "foo.jpg" }
  file_updated_at   { Time.now }
  file_extension {
    FileExtension.find_by_extension( "jpg" ) || FileExtension.make!
  }
  file_prefix {
    FilePrefix.find_by_prefix( "http://staticdev.inaturalist.org/photos/" ) || FilePrefix.make!
  }
end

Message.blueprint do
  from_user { User.make! }
  to_user { User.make! }
  subject { Faker::Lorem.sentence }
  body { Faker::Lorem.paragraph }
end

ModeratorAction.blueprint do
  user { make_curator }
  resource { Comment.make! }
  action { ModeratorAction::HIDE }
  reason { Faker::Lorem.sentence }
end

ModeratorNote.blueprint do
  user { make_curator }
  body { Faker::Lorem.paragraph }
  subject_user { User.make! }
end

MushroomObserverImportFlowTask.blueprint do
  user { User.make! }
end

OauthApplication.blueprint do
  name { Faker::Lorem.sentence }
  owner { User.make }
  url { "http://#{Faker::Internet.domain_name}" }
  redirect_uri { Doorkeeper.configuration.native_redirect_uri }
end

Observation.blueprint do
  user { User.make! }
  license { Observation::CC_BY }
  description { Faker::Lorem.sentence }
end

ObservationField.blueprint do
  name { Faker::Lorem.sentence }
  datatype {'text'}
  user { User.make! }
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

ObservationReview.blueprint do
  observation { Observation.make }
  user { User.make! }
end

ObservationSound.blueprint do
  observation { Observation.make }
  sound { Sound.make }
end

ObservationsExportFlowTask.blueprint do
  user { User.make! }
end

Photo.blueprint do
  user { User.make }
end

FlickrPhoto.blueprint do
  user { User.make! }
  native_photo_id { rand(1000) }
end

FacebookPhoto.blueprint do
  user { User.make! }
  native_photo_id { rand(1000) }
end

PicasaPhoto.blueprint do
  user { User.make! }
  native_photo_id { rand(1000) }
end

PhotoMetadata.blueprint do
  photo { Photo.make! }
end

Place.blueprint do
  name { Faker::Lorem.sentence }
  latitude { rand(90) }
  longitude { rand(180) }
end

PlaceTaxonName.blueprint do
  place { make_place_with_geom }
  taxon_name { TaxonName.make! }
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
  user { UserPrivilege.make!( privilege: UserPrivilege::ORGANIZER ).user }
  title { Faker::Lorem.sentence }
  description { Faker::Lorem.paragraph.truncate(255) }
end

Project.blueprint(:collection) do
  project_type { "collection" }
end

ProjectList.blueprint do
  project { Project.make }
end

ProjectObservation.blueprint do
  observation { Observation.make! }
  project { Project.make! } 
end

ProjectObservationField.blueprint do
  project { Project.make! }
  observation_field { ObservationField.make! }
end

ProjectObservationRule.blueprint do
  ruler { Project.make! }
  operator { "identified?" }
end

ProjectUser.blueprint do
  user { User.make! }
  project { Project.make! }
end

ProjectUserInvitation.blueprint do
  user { User.make! }
  invited_user { User.make! }
  project { Project.make! }
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

SavedLocation.blueprint do
  user { User.make! }
  title { Faker::Name.name }
  latitude { rand(90) }
  longitude { rand(180) }
end

Site.blueprint do
  domain = Faker::Internet.domain_name
  name { Faker::Name.name }
  domain { domain }
  url { "http://#{domain}" }
end

SiteAdmin.blueprint do
  user { User.make! }
  site { Site.make! }
end

SiteFeaturedProject.blueprint do
  project { Project.make! }
  site { Site.make! }
  user { User.make! }
end

SiteStatistic.blueprint do
  data { {
    observations: { },
    users: { },
    projects: { },
    taxa: { }
  }}
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
  name { Faker::Name.name.gsub( /[^(A-z|\s|\-|×)]/, "" ) }
  rank { Taxon::RANKS[rand(Taxon::RANKS.size)] }
  is_active { true }
end

Taxon.blueprint(:species) do
  rank {"species"}
end

TaxonChange.blueprint do
  source { Source.make! }
  user { make_curator }
end

TaxonCurator.blueprint do
  taxon_framework { TaxonFramework.make! }
  user { make_curator }
end

TaxonFramework.blueprint do
  taxon { Taxon.make! }
  rank_level { 5 }
  source { Source.make! }
end

TaxonFrameworkRelationship.blueprint do
  taxon_framework { TaxonFramework.make! }
end

TaxonDrop.blueprint do
  source { Source.make! }
  user { make_curator }
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
  user { make_curator }
end

TaxonName.blueprint do
  name { Faker::Name.name.gsub( /[^(A-z|\s|\-|×)]/, "" ) }
  taxon { Taxon.make! }
  lexicon { TaxonName::ENGLISH }
end

TaxonRange.blueprint do
  taxon { Taxon.make! }
  source { Source.make }
end

TaxonScheme.blueprint do
  title { Faker::Lorem.sentence }
  source { Source.make! }
end

TaxonSchemeTaxon.blueprint do
  taxon_scheme { TaxonScheme.make! }
  taxon { Taxon.make! }
  source_identifier { rand(1000) }
end

TaxonSplit.blueprint do
  source { Source.make! }
  user { make_curator }
end

TaxonStage.blueprint do
  source { Source.make! }
  user { make_curator }
end

TaxonSwap.blueprint do
  source { Source.make! }
  user { make_curator }
end

Trip.blueprint do
  user { User.make! }
  parent { self.user }
  title { Faker::Lorem.sentence }
  body { Faker::Lorem.paragraph }
  published_at { Time.now }
  start_time { 8.hours.ago }
  stop_time { 2.hours.ago }
end

TripTaxon.blueprint do
  trip { Trip.make! }
  taxon { Taxon.make! }
end

TripPurpose.blueprint do
  trip { Trip.make! }
  resource { Taxon.make! }
end

UpdateAction.blueprint do
  o = Observation.make!
  resource { o }
  notifier { Comment.make!(:parent => o) }
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
  confirmed_at { 5.days.ago.to_s(:db) }
  confirmation_sent_at { 5.days.ago.to_s(:db) }
  confirmation_token { Faker::Alphanumeric.alphanumeric }
end

UserBlock.blueprint do
  user { User.make! }
  blocked_user { User.make! }
end

UserMute.blueprint do
  user { User.make! }
  muted_user { User.make! }
end

UserParent.blueprint do
  email { Faker::Internet.email }
  name { Faker::Name.name }
  child_name { Faker::Name.name }
  user { User.make! }
end

UserPrivilege.blueprint do
  user { User.make! }
  privilege { UserPrivilege::SPEECH }
end

WikiPage.blueprint do
  t = Faker::Lorem.sentence
  title { t }
  path { t.parameterize }
  creator { User.make! }
end
