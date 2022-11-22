# frozen_string_literal: true

require "spec_helper"

describe Site do
  it { is_expected.to have_many( :observations ).inverse_of :site }
  it { is_expected.to have_many( :users ).inverse_of :site }
  it { is_expected.to have_many( :site_admins ).inverse_of :site }
  it { is_expected.to have_many( :posts ).dependent :destroy }
  it { is_expected.to have_many( :journal_posts ).class_name( "Post" ).dependent :destroy }
  it { is_expected.to have_many( :site_featured_projects ).dependent :destroy }
  it { is_expected.to have_and_belong_to_many :announcements }
  it { is_expected.to belong_to( :place ).inverse_of :sites }
  it { is_expected.to have_many( :places_sites ).dependent :destroy }
  it { is_expected.to have_many( :export_places_sites ).class_name( "PlacesSite" ) }
  it { is_expected.to have_many( :export_places ).through( :export_places_sites ).source( :place ) }
  it { is_expected.to belong_to( :taxon_range_source ).class_name( "Source" ).with_foreign_key "source_id" }
end
