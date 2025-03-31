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

  # this is maybe out of place, but these tests are targeting behavior in our forked version
  # of the `preferences` gem that we should make sure it preserved in future upgrades
  describe "preferences" do
    let( :site ) do
      site = Site.make!
      site.update( preferred_site_name_short: "TestSite" )
      site
    end

    it "can save preferences" do
      expect( site.preferred_site_name_short ).to eq "TestSite"
    end

    # test Preferences::InstanceMethods.preferences
    it "does not raise an error when preferences exist but are no longer defined" do
      expect( site.preferred_site_name_short ).to eq "TestSite"
      preferences = site.instance_variable_get( "@preferences" )
      preferences[nil]["previously_defined"] = true
      Preference.create( name: "previously_defined", owner: site, value: "t" )

      site.reload
      # simulate setting the `site` preferences instance variable to what it would be if restored
      # from a cached instance with the preference `previously_defined` were defined, and where
      # the perference is still in the database, but not currently defined. Without our forked
      # version of the preferences gem this would raise an error:
      #   `undefined method `type_cast' for nil`
      site.instance_variable_set( "@preferences", preferences )
      expect( site.preferred_site_name_short ).to eq "TestSite"
    end

    # tests Preference.touch_owner
    it "touches the record when preferences are updated" do
      expect( site.preferred_site_name_short ).to eq "TestSite"
      original_updated_at = site.updated_at
      site.stored_preferences.last.update( value: "NewName" )
      expect( site.updated_at ).to_not eq original_updated_at
    end
  end
end
