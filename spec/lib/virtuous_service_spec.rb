# frozen_string_literal: true

require "spec_helper"
require "virtuous_service"

describe VirtuousService do
  let( :direct_donor_user ) { User.make! }
  let( :passthrough_donor_user ) { User.make! }
  let( :non_user_parent_email ) { Faker::Internet.email }
  let( :gifts ) do
    [{
      "id" => 1,
      "contactId" => 1,
      "giftDate" => "9/24/2026"
    }, {
      "id" => 2,
      "contactId" => 2,
      "giftDate" => "9/23/2026"
    }, {
      "id" => 3,
      "contactId" => 4,
      "giftDate" => "9/22/2026"
    }]
  end
  let( :contacts ) do
    [{
      "id" => 1,
      "contactType" => "Household",
      "contactIndividuals" => [{
        "contactMethods" => [{
          "type" => "email",
          "value" => direct_donor_user.email
        }]
      }]
    }, {
      "id" => 2,
      "contactType" => "Not Household"
    }, {
      "id" => 3,
      "contactType" => "Household",
      "contactIndividuals" => [{
        "contactMethods" => [{
          "type" => "email",
          "value" => passthrough_donor_user.email
        }]
      }]
    }, {
      "id" => 4,
      "contactType" => "Household",
      "contactIndividuals" => [{
        "contactMethods" => [{
          "type" => "email",
          "value" => non_user_parent_email
        }]
      }]
    }]
  end
  let( :full_gifts ) do
    [{
      "id" => 2,
      "contactId" => 2,
      "giftPassthroughs" => [{
        "contactId" => 3
      }]
    }]
  end

  before do
    allow_any_instance_of( VirtuousService ).to receive( :fetch_api_post_response ).and_return( {} )
    allow_any_instance_of( VirtuousService ).to receive( :fetch_api_post_response ).
      with( "#{VirtuousService::GIFT_QUERY_ENDPOINT}?take=1000", anything ) do | _service, _url, post_body |
        paging = post_body[:groups].first[:conditions].any? {| c | c[:parameter] == "Gift Id" }
        paging ? {} : { "total" => gifts.length, "list" => gifts }
      end
    allow_any_instance_of( VirtuousService ).to receive( :fetch_api_post_response ).
      with( "#{VirtuousService::FULL_CONTACT_ENDPOINT}?take=1000", any_args ) do | _service, _url, _post_body |
        { "total" => contacts.length, "list" => contacts }
      end
    allow_any_instance_of( VirtuousService ).to receive( :fetch_api_post_response ).
      with( "#{VirtuousService::FULL_GIFT_QUERY_ENDPOINT}?take=1000", any_args ) do | _service, _url, _post_body |
        { "total" => full_gifts.length, "list" => full_gifts }
      end
  end

  describe "initialize" do
    it "creates an instance" do
      virtuous_service = VirtuousService.new
      expect( virtuous_service ).to be_an_instance_of( VirtuousService )
    end
  end

  describe "fetch_donors" do
    let( :virtuous_service ) { VirtuousService.new }

    describe "dry run" do
      let( :virtuous_service ) { VirtuousService.new( dry_run: true ) }
      it "does not mark donors on a dry run" do
        expect( direct_donor_user.donor? ).to be false
        expect( UserDonation.count ).to eq 0
        virtuous_service.fetch_donors
        direct_donor_user.reload
        expect( direct_donor_user.donor? ).to be false
        expect( UserDonation.count ).to eq 0
      end
    end

    it "marks direct donor users as donors" do
      direct_donor_gift = gifts.first
      expect( direct_donor_user.donor? ).to be false
      expect( UserDonation.where( user: direct_donor_user ).count ).to eq 0

      virtuous_service.fetch_donors
      direct_donor_user.reload
      expect( direct_donor_user.donor? ).to be true
      expect( direct_donor_user.virtuous_donor_contact_id ).to eq direct_donor_gift["contactId"]
      expect( UserDonation.where( user: direct_donor_user ).count ).to eq 1
      expect( UserDonation.where( user: direct_donor_user ).first.donated_at ).
        to eq( Date.strptime( direct_donor_gift["giftDate"], "%m/%e/%Y" ) )
    end

    it "does not override existing virtuous_donor_contact_id" do
      direct_donor_gift = gifts.first
      direct_donor_contact_id = direct_donor_gift["contactId"]
      preexisting_virtuous_donor_contact_id = direct_donor_contact_id + 1000
      direct_donor_user.update( virtuous_donor_contact_id: preexisting_virtuous_donor_contact_id )
      expect( direct_donor_user.virtuous_donor_contact_id ).not_to eq direct_donor_contact_id
      expect( direct_donor_user.donor? ).to be true

      virtuous_service.fetch_donors
      direct_donor_user.reload
      expect( direct_donor_user.donor? ).to be true
      expect( direct_donor_user.virtuous_donor_contact_id ).to eq preexisting_virtuous_donor_contact_id
    end

    it "marks passthrough donor users as donors" do
      passthrough_donor_gift = gifts[1]
      passthrough_donor_contact = contacts[2]
      expect( passthrough_donor_user.donor? ).to be false
      expect( UserDonation.where( user: passthrough_donor_user ).count ).to eq 0

      virtuous_service.fetch_donors
      passthrough_donor_user.reload
      expect( passthrough_donor_user.donor? ).to be true
      expect( passthrough_donor_user.virtuous_donor_contact_id ).to eq passthrough_donor_contact["id"]
      expect( UserDonation.where( user: passthrough_donor_user ).count ).to eq 1
      expect( UserDonation.where( user: passthrough_donor_user ).first.donated_at ).
        to eq( Date.strptime( passthrough_donor_gift["giftDate"], "%m/%e/%Y" ) )
    end

    it "marks user parents as donors via user" do
      user_parent = UserParent.make!( parent_user: direct_donor_user )
      user_parent_gift = gifts[0]
      expect( direct_donor_user.donor? ).to be false
      expect( user_parent.donor? ).to be false

      virtuous_service.fetch_donors
      direct_donor_user.reload
      user_parent.reload
      expect( direct_donor_user.donor? ).to be true
      expect( user_parent.donor? ).to be true
      expect( user_parent.virtuous_donor_contact_id ).to eq user_parent_gift["contactId"]
    end

    it "marks user parents as donors via email" do
      non_user_parent_gift = gifts[2]
      user_parent = UserParent.make!( email: non_user_parent_email )
      expect( User.where( email: non_user_parent_email ).count ).to eq 0
      expect( user_parent.donor? ).to be false

      virtuous_service.fetch_donors
      user_parent.reload
      expect( user_parent.donor? ).to be true
      expect( user_parent.virtuous_donor_contact_id ).to eq non_user_parent_gift["contactId"]
    end

    it "does not create duplicate donations when run twice" do
      virtuous_service.fetch_donors
      expect( UserDonation.count ).to be_positive
      expect { VirtuousService.new.fetch_donors }.not_to change( UserDonation, :count )
    end
  end
end
