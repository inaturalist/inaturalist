# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper.rb"

describe Emailer, "updates_notification" do
  include ActionView::Helpers::TextHelper
  elastic_models( Taxon, Observation )
  before( :all ) do
    DatabaseCleaner.clean_with( :truncation, except: %w(spatial_ref_sys) )
  end
  before do
    enable_has_subscribers
    @observation = Observation.make!
    @comment = without_delay { Comment.make!( parent: @observation ) }
    @user = @observation.user
  end
  after { disable_has_subscribers }

  it "should use common names for a user's place" do
    p = make_place_with_geom
    t = Taxon.make!
    tn_default = TaxonName.make!( taxon: t, lexicon: TaxonName::LEXICONS[:ENGLISH], name: "Default Name" )
    tn_local = TaxonName.make!( taxon: t, lexicon: TaxonName::LEXICONS[:ENGLISH], name: "Localized Name" )
    PlaceTaxonName.make!( taxon_name: tn_local, place: p )
    @user.update( place_id: p.id )
    without_delay { Identification.make!( taxon: t, observation: @observation ) }
    mail = Emailer.updates_notification( @user, @user.recent_notifications )
    expect( mail.body ).to match( /#{tn_local.name}/ )
    expect( mail.body ).not_to match( /#{tn_default.name}/ )
  end

  it "sends updates on observation field values, in all languages" do
    @ofv = nil
    without_delay { @ofv = ObservationFieldValue.make!( observation: @observation, user: User.make! ) }
    I18N_SUPPORTED_LOCALES.each do | loc |
      @user.update( locale: loc )
      mail = Emailer.updates_notification( @user, @user.recent_notifications )
      expect( mail.body ).to include I18n.t( :user_added_an_observation_field_html,
        user: ApplicationController.helpers.link_to( @ofv.user.login, UrlHelper.person_url( @ofv.user, host: Site.default.url ) ),
        field_name: @ofv.observation_field.name.truncate( 30 ),
        owner: @user.login,
        locale: loc )
    end
    @user.update( locale: "en" )
  end

  it "should translate the subject" do
    locale_was = @user.locale
    @user.update( locale: "es" )
    mail = Emailer.updates_notification( @user, @user.recent_notifications )
    expect( mail.subject ).to include "Nuevas"
    @user.update( locale: locale_was )
  end

  describe "with a site" do
    before do
      @site = Site.make!( preferred_locale: "es-MX" )
      expect( @site.logo_email_banner ).to receive( :url ).at_least( :once ).and_return( "bird.png" )
      @user.site = @site
      @user.save!
    end

    it "should use the user's site logo" do
      expect( @user.site ).to eq @site
      expect( @user.site.logo_email_banner.url ).to include( "bird.png" )
      mail = Emailer.updates_notification( @user, @user.recent_notifications )
      expect( mail.body ).to match @site.logo_email_banner.url
    end

    it "should use the user's site url as the base url" do
      mail = Emailer.updates_notification( @user, @user.recent_notifications )
      expect( mail.body ).to match @site.url
    end

    it "should include site name in subject" do
      mail = Emailer.updates_notification( @user, @user.recent_notifications )
      expect( mail.subject ).to match @site.name
    end
  end

  describe "with curator change" do
    let( :project ) { Project.make! }
    def test_user_with_project_and_viewer( user, project, viewer )
      viewer_pu = ProjectUser.make!( user: viewer, project: project )
      pu = if user == viewer
        viewer_pu
      else
        ProjectUser.make!( user: user, project: project )
      end
      # Test change to curator
      pu.update( role: ProjectUser::CURATOR )
      Delayed::Job.all.each {| j | Delayed::Worker.new.run( j ) }
      mail = Emailer.updates_notification( viewer, viewer.recent_notifications )
      expect( mail.body ).to match( /curator/ )
      # Test change to manage
      pu.update( role: ProjectUser::MANAGER )
      Delayed::Job.all.each {| j | Delayed::Worker.new.run( j ) }
      mail = Emailer.updates_notification( viewer, viewer.recent_notifications )
      expect( mail.body ).to match( /manager/ )
      # Test change to admin
      project.update( user: user )
      Delayed::Job.all.each {| j | Delayed::Worker.new.run( j ) }
      mail = Emailer.updates_notification( viewer, viewer.recent_notifications )
      expect( mail.body ).to match( /admin/ )
    end
    it "should work when it's about you" do
      u = User.make!
      test_user_with_project_and_viewer( u, Project.make!, u )
    end
    it "should work when it's about someone else" do
      test_user_with_project_and_viewer( User.make!, Project.make!, User.make! )
    end
  end
end

describe Emailer, "new_message" do
  it "should work" do
    m = make_message
    mail = Emailer.new_message( m )
    expect( mail.body ).not_to be_blank
  end

  it "should not deliver flagged messages" do
    from_user = make_user_with_privilege( UserPrivilege::SPEECH )
    to_user = User.make!
    m = make_message( from_user: from_user, to_user: to_user, user: from_user )
    m.send_message
    m.flags.create( flag: "spam" )
    m.reload
    mail = Emailer.new_message( m )
    expect( mail.body ).to be_blank
  end

  it "should not deliver if from_user is suspended" do
    m = make_message
    m.from_user.suspend!
    mail = Emailer.new_message( m )
    expect( mail.body ).to be_blank
  end

  it "does not raise en error if the message is missing" do
    expect do
      Emailer.new_message( nil ).deliver_now
    end.to_not raise_error
  end
end

describe Emailer, "project_user_invitation" do
  it "should work if the sender no longer exists" do
    pui = ProjectUserInvitation.make!
    pui.user.destroy
    pui.reload
    expect( pui.user ).to be_blank
    mail = Emailer.project_user_invitation( pui )
    expect( mail.body ).not_to be_blank
  end
end

describe Emailer, "bulk_observation_success" do
  let( :user ) { User.make! }
  it "should mention the filename" do
    mail = Emailer.bulk_observation_success( user, "the_filename" )
    expect( mail.body ).to match( /the_filename/ )
    expect( mail.subject ).to match( /the_filename/ )
  end

  describe "with a site" do
    before do
      @site = Site.make!( preferred_locale: "es-MX", name: "Superbo" )
      expect( @site.logo_email_banner ).to receive( :url ).at_least( :once ).and_return( "bird.png" )
      user.site = @site
      user.save!
    end
    it "should include the site name" do
      mail = Emailer.bulk_observation_success( user, "the_filename" )
      expect( mail.body ).to match( /#{@site.name}/ )
    end
  end
end

describe Emailer, "bulk_observation_error" do
  it "should mention the error reasons" do
    user = User.make!
    bof = BulkObservationFile.new( nil, user.id )
    o = Observation.new
    expect( o ).not_to be_valid
    e = BulkObservationFile::BulkObservationException.new(
      "failed to process",
      1,
      [BulkObservationFile::BulkObservationException.new( "observation was invalid", 1, o.errors )]
    )
    errors = bof.collate_errors( e )
    mail = Emailer.bulk_observation_error( user, "the_filename", errors )
    expect( mail.subject ).to match( /the_filename/ )
    expect( mail.body ).to match( /failed to process/ )
  end
end
