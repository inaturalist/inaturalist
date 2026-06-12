# frozen_string_literal: true

require "spec_helper"

describe AdditionalObserver do
  it { is_expected.to belong_to( :observation ) }
  it { is_expected.to belong_to( :user ) }
  it { is_expected.to belong_to( :added_by_user ).class_name "User" }

  it { is_expected.to validate_presence_of( :observation ) }
  it { is_expected.to validate_presence_of( :user ) }
  it { is_expected.to validate_presence_of( :added_by_user ) }

  it "is valid when the creator adds another user" do
    expect( AdditionalObserver.make! ).to be_valid
  end

  describe "uniqueness" do
    it "does not allow the same user to be added twice to one observation" do
      existing = AdditionalObserver.make!
      duplicate = AdditionalObserver.new(
        observation: existing.observation,
        user: existing.user,
        added_by_user: existing.added_by_user
      )
      expect( duplicate ).not_to be_valid
      expect( duplicate.errors[:user_id] ).not_to be_empty
    end

    it "allows the same user to be an additional observer on different observations" do
      first = AdditionalObserver.make!
      other_observation = Observation.make!
      second = AdditionalObserver.new(
        observation: other_observation,
        user: first.user,
        added_by_user: other_observation.user
      )
      expect( second ).to be_valid
    end
  end

  describe "user_is_not_the_creator" do
    it "does not allow the creator to be their own additional observer" do
      observation = Observation.make!
      ao = AdditionalObserver.new(
        observation: observation,
        user: observation.user,
        added_by_user: observation.user
      )
      expect( ao ).not_to be_valid
      expect( ao.errors[:user] ).not_to be_empty
    end
  end

  describe "added_by_user_is_the_creator" do
    it "does not allow a non-creator to add an additional observer" do
      observation = Observation.make!
      ao = AdditionalObserver.new(
        observation: observation,
        user: User.make!,
        added_by_user: User.make!
      )
      expect( ao ).not_to be_valid
      expect( ao.errors[:added_by_user] ).not_to be_empty
    end
  end

  describe "dependent destroy" do
    it "is destroyed when the observation is destroyed" do
      ao = AdditionalObserver.make!
      observation = ao.observation
      observation.destroy
      expect( AdditionalObserver.find_by_id( ao.id ) ).to be_nil
    end

    it "is destroyed when the additional observer user is destroyed" do
      ao = AdditionalObserver.make!
      user = ao.user
      user.destroy
      expect( AdditionalObserver.find_by_id( ao.id ) ).to be_nil
    end
  end

  describe "elastic indexing" do
    elastic_models( Observation )

    it "indexes the additional observer on the observation after create" do
      observation = Observation.make!
      user = User.make!
      AdditionalObserver.make!(
        observation_id: observation.id,
        user_id: user.id,
        added_by_user_id: observation.user_id
      )
      result = Observation.elastic_search( where: { id: observation.id } ).results.results.first
      expect( result.additional_observer_ids ).to include( user.id )
    end

    it "removes the additional observer from the observation index after destroy" do
      observation = Observation.make!
      user = User.make!
      ao = AdditionalObserver.make!(
        observation_id: observation.id,
        user_id: user.id,
        added_by_user_id: observation.user_id
      )
      ao.destroy
      result = Observation.elastic_search( where: { id: observation.id } ).results.results.first
      expect( result.additional_observer_ids ).not_to include( user.id )
    end
  end
end
