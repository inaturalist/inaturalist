# frozen_string_literal: true

require "spec_helper"

describe "moderator_actions/hide_content" do
  let( :admin ) { make_admin }
  let( :another_admin ) { make_admin }
  before do
    sign_in admin
  end
  after do
    sign_out admin
  end

  describe "localsound" do
    let( :owner ) { User.make!( login: "tester" ) }
    let( :item ) { LocalSound.make!( user: owner, license: Sound::CC0 ) }
    before do
      item.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "pika.mp3" ) )
      assign( :item, item )
    end

    it "unhidden shows audio file" do
      render

      expect( rendered ).to have_tag( "audio" ) do
        with_tag "source", src: item.file.url
      end
      expect( rendered ).not_to have_tag( "i", with: { class: "content-hidden" } )
    end

    it "hidden shows content hidden action" do
      moderator_action = ModeratorAction.make!( user: another_admin, resource: item,
        action: ModeratorAction::HIDE, created_at: Time.now )
      item.moderator_actions = [moderator_action]

      render

      expect( rendered ).to have_tag( "i", with: { class: "content-hidden" } )
      expect( rendered ).not_to have_tag( "audio" )
    end
  end

  describe "soundcloudsound" do
    let( :sound_url ) { "https://#{Faker::Internet.domain_name}/sound2.mp3" }
    let( :item ) { SoundcloudSound.make!( native_page_url: sound_url ) }
    before do
      assign( :item, item )
    end

    it "unhidden shows audio file" do
      render

      expect( rendered ).to have_tag( "iframe", with: { title: "Soundcloud" } )
      expect( rendered ).not_to have_tag( "i", with: { class: "content-hidden" } )
    end

    it "hidden shows content hidden action" do
      moderator_action = ModeratorAction.make!( user: another_admin, resource: item,
        action: ModeratorAction::HIDE, created_at: Time.now )
      item.moderator_actions = [moderator_action]

      render

      expect( rendered ).to have_tag( "i", with: { class: "content-hidden" } )
      expect( rendered ).not_to have_tag( "iframe", with: { title: "Soundcloud" } )
    end
  end
end
