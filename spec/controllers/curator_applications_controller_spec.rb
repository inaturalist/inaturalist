# frozen_string_literal: true

require "spec_helper"

describe CuratorApplicationsController do
  def stub_idents_count
    allow( Identification ).to receive( :elastic_search ) {
      OpenStruct.new_recursive(
        total_entries: 500
      )
    }
  end

  let( :eligible_user ) do
    user = create :user, created_at: 100.days.ago
    allow( user ).to receive( :flags ) { OpenStruct.new_recursive( count: 10 ) }
    5.times { create( :flag, user: user ) }
    stub_idents_count
    user
  end

  describe "new" do
    render_views

    it "should show an error about account age if user signed up in the last 60 days" do
      user = create :user
      stub_idents_count
      5.times { create( :flag, user: user ) }
      sign_in user
      get :new
      expect( assigns( :eligible ) ).to be false
      expect( response.body ).to match /60\s+days/m
    end

    it "should show an error message about flags if viewer has fewer than 5 flags" do
      user = create :user, created_at: 100.days.ago
      stub_idents_count
      sign_in user
      expect( user.flags.count ).to be < 5
      get :new
      expect( assigns( :eligible ) ).to be false
      expect( response.body ).to include "at least 5 flags"
    end

    it "should show an error message about idents if viewer has fewer than 100 improving idents" do
      user = create :user, created_at: 100.days.ago
      5.times { create( :flag, user: user ) }
      sign_in user
      get :new
      expect( assigns( :eligible ) ).to be false
      expect( response.body ).to match /100\s+improving\s+identifications/m
    end

    it "should not sure show an error if the user is eligible" do
      sign_in eligible_user
      get :new
      expect( assigns( :eligible ) ).to be true
      expect( response.body ).not_to include "return here"
    end
  end

  describe "create" do
    it "should not deliver an email if the explanation is less than required length" do
      sign_in eligible_user
      expect do
        post :create, params: { application: {
          application: CuratorApplicationsController::FIELDS.each_with_object( {} ) do | field, memo |
            memo[field] = Faker::Lorem.sentence
          end.merge( explanation: "a" )
        } }
      end.not_to change( ActionMailer::Base.deliveries, :size )
    end

    it "should not deliver an email if user is not eligible" do
      sign_in create( :user )
      expect do
        post :create, params: {
          application: CuratorApplicationsController::FIELDS.each_with_object( {} ) do | field, memo |
            memo[field] = Faker::Lorem.sentence
          end
        }
      end.not_to change( ActionMailer::Base.deliveries, :size )
    end

    it "should deliver an email if form is complete and user is eligible" do
      sign_in eligible_user
      expect do
        post :create, params: { application: {
          explanation: Faker::Lorem.sentence( word_count: 10 ),
          taxonomy_examples: Faker::Lorem.sentence,
          name_examples: Faker::Lorem.sentence,
          moderation_examples: Faker::Lorem.sentence
        } }
      end.to change( ActionMailer::Base.deliveries, :size ).by 1
    end
  end
end
