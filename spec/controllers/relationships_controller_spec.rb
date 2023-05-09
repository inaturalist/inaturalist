# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe RelationshipsController do
  render_views
  describe "index" do
    describe "while signed in" do
      let( :user ) { create :user }
      before do
        sign_in user
      end
      it "should load" do
        get :index
        expect( response ).to be_successful
      end
      it "should load when user follows someone" do
        create :friendship, user: user
        get :index
        expect( response ).to be_successful
      end
      it "should load when the user is followed by someone" do
        create :friendship, friend: user
        get :index
        expect( response ).to be_successful
      end
    end
  end
end
