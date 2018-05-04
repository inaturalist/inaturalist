# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Emailer, "updates_notification" do
  include ActionView::Helpers::TextHelper
  before(:all) do
    DatabaseCleaner.clean_with(:truncation, except: %w[spatial_ref_sys])
  end
  before do
    @observation = Observation.make!
    @comment = without_delay { Comment.make!(:parent => @observation) }
    @user = @observation.user
    enable_elastic_indexing( UpdateAction, Taxon )
  end
  after(:each) { disable_elastic_indexing( UpdateAction, Taxon ) }
  
  it "should work when recipient has a blank locale" do
    @user.update_attributes(:locale => "")
    expect(@user.update_subscribers.all).not_to be_blank
    mail = Emailer.updates_notification(@user, @user.update_subscriber_actions.all)
    expect(mail.body).not_to be_blank
  end

  it "should use common names for a user's place" do
    p = Place.make!
    t = Taxon.make!
    tn_default = TaxonName.make!( taxon: t, lexicon: TaxonName::LEXICONS[:ENGLISH], name: "Default Name" )
    tn_local = TaxonName.make!( taxon: t, lexicon: TaxonName::LEXICONS[:ENGLISH], name: "Localized Name" )
    ptn = PlaceTaxonName.make!( taxon_name: tn_local, place: p )
    @user.update_attributes( place_id: p.id )
    identification = without_delay { Identification.make!( taxon: t, observation: @observation ) }
    update_action = @user.update_subscriber_actions.where( notifier: identification ).first
    mail = Emailer.updates_notification( @user, [update_action] )
    expect( mail.body ).to match /#{tn_local.name}/
    expect( mail.body ).not_to match /#{tn_default.name}/
  end

  it "sends updates on observation field values, in all languages" do
    @ofv = nil
    without_delay { @ofv = ObservationFieldValue.make!(observation: @observation, user: User.make!) }
    I18N_SUPPORTED_LOCALES.each do |loc|
      @user.update_attributes(locale: loc)
      mail = Emailer.updates_notification(@user, [@user.update_subscriber_actions.last])
      expect(mail.body).to include I18n.t(:user_added_an_observation_field_html,
        user: FakeView.link_to(@ofv.user.login, FakeView.person_url(@ofv.user, host: Site.default.url)),
        field_name: @ofv.observation_field.name.truncate(30),
        owner: @user.login,
        locale: loc)
    end
    @user.update_attributes(locale: "en")
  end

  describe "with a site" do
    before do
      @site = Site.make!(:preferred_locale => "es-MX")
      expect(@site.logo_email_banner).to receive(:url).at_least(:once).and_return("foo.png")
      @user.site = @site
      @user.save!
    end

    it "should use the user's site logo" do
      mail = Emailer.updates_notification(@user, @user.update_subscriber_actions.all)
      expect(mail.body).to match @site.logo_email_banner.url
    end

    it "should use the user's site url as the base url" do
      mail = Emailer.updates_notification(@user, @user.update_subscriber_actions.all)
      expect(mail.body).to match @site.url
    end

    it "should default to the user's site locale if the user has no locale" do
      @user.update_attributes(:locale => "")
      mail = Emailer.updates_notification(@user, @user.update_subscriber_actions.all)
      expect(mail.body).to match /Nuevas actualizaciones/
    end

    it "should include site name in subject" do
      @user.update_attributes(:locale => "")
      mail = Emailer.updates_notification(@user, @user.update_subscriber_actions.all)
      expect(mail.subject).to match @site.name
    end
  end
end

describe Emailer, "new_message" do
  it "should work" do
    m = make_message
    mail = Emailer.new_message(m)
    expect(mail.body).not_to be_blank
  end

  it "should not deliver flagged messages" do
    from_user = User.make!
    to_user = User.make!
    m = make_message(:from_user => from_user, :to_user => to_user, :user => from_user)
    m.send_message
    f = m.flags.create(:flag => "spam")
    m.reload
    mail = Emailer.new_message(m)
    expect(mail.body).to be_blank
  end

  it "should not deliver if from_user is suspended" do
    m = make_message
    m.from_user.suspend!
    mail = Emailer.new_message(m)
    expect(mail.body).to be_blank
  end
end

describe Emailer, "invite" do
  it "should work" do
    user = User.make!
    address = "foo@bar.com"
    params = {
      :sender_name => "Admiral Akbar",
      :personal_message => "it's a twap"
    }
    mail = Emailer.invite_user(address, params, user)
    expect(mail.body).not_to be_blank
  end
end

describe Emailer, "project_user_invitation" do
  it "should work if the sender no longer exists" do
    pui = ProjectUserInvitation.make!
    pui.user.destroy
    pui.reload
    expect(pui.user).to be_blank
    mail = Emailer.project_user_invitation(pui)
    expect(mail.body).not_to be_blank
  end
end

describe Emailer, "bulk_observation_success" do
  let(:user) { User.make! }
  it "should mention the filename" do
    mail = Emailer.bulk_observation_success(user, "the_filename")
    expect(mail.body).to match /the_filename/
    expect(mail.subject).to match /the_filename/
  end

  describe "with a site" do
    before do
      @site = Site.make!(:preferred_locale => "es-MX")
      expect(@site.logo_email_banner).to receive(:url).and_return("foo.png")
      user.site = @site
      user.save!
    end
    it "should include the site name" do
      mail = Emailer.bulk_observation_success(user, "the_filename")
      expect(mail.body).to match /#{@site.name}/
    end
  end
end

describe Emailer, "bulk_observation_error" do
  it "should mention the error reasons" do
    user = User.make!
    bof = BulkObservationFile.new(nil, user.id)
    o = Observation.new
    expect(o).not_to be_valid
    e = BulkObservationFile::BulkObservationException.new(
      "failed to process", 
      1, 
      [BulkObservationFile::BulkObservationException.new("observation was invalid", 1, o.errors)]
    )
    errors = bof.collate_errors(e)
    mail = Emailer.bulk_observation_error(user, "the_filename", errors)
    expect(mail.subject).to match /the_filename/
    expect(mail.body).to match /failed to process/
  end
end
