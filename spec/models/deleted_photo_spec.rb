# frozen_string_literal: true

require "spec_helper"

describe DeletedPhoto do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :photo }

  describe "eligible_for_removal?" do
    it "returns false if the photo is already removed" do
      expect(
        DeletedPhoto.make!(
          created_at: 1.year.ago
        ).eligible_for_removal?
      ).to be true
      expect(
        DeletedPhoto.make!(
          created_at: 1.year.ago,
          removed_from_s3: true
        ).eligible_for_removal?
      ).to be false
    end

    it "returns false if the photo is orphaned but deleted more recently than 1 month" do
      expect(
        DeletedPhoto.make!(
          created_at: ( 1.month - 1.day ).ago,
          orphan: true
        ).eligible_for_removal?
      ).to be false
      expect(
        DeletedPhoto.make!(
          created_at: ( 1.month + 1.day ).ago,
          orphan: true
        ).eligible_for_removal?
      ).to be true
    end

    it "returns false if the photo is not orphaned but deleted more recently than 6 months" do
      expect(
        DeletedPhoto.make!(
          created_at: ( 6.months - 1.day ).ago,
          orphan: false
        ).eligible_for_removal?
      ).to be false
      expect(
        DeletedPhoto.make!(
          created_at: ( 6.months + 1.day ).ago,
          orphan: false
        ).eligible_for_removal?
      ).to be true
    end

    it "returns false if the photo is set to private but deleted more recently than 2 months" do
      photo = LocalPhoto.make!
      ModeratorAction.create(
        action: ModeratorAction::HIDE,
        resource: photo,
        user: make_admin,
        reason: Faker::Lorem.sentence,
        private: true
      )
      photo.destroy
      expect(
        DeletedPhoto.make!(
          created_at: ( 2.months - 1.day ).ago,
          orphan: false,
          photo_id: photo.id
        ).eligible_for_removal?
      ).to be false
      expect(
        DeletedPhoto.make!(
          created_at: ( 2.months + 1.day ).ago,
          orphan: false,
          photo_id: photo.id
        ).eligible_for_removal?
      ).to be true
    end

    it "returns false if the resource still exists" do
      photo = LocalPhoto.make!
      expect(
        DeletedPhoto.make!(
          created_at: 1.year.ago,
          photo_id: photo.id,
          removed_from_s3: false
        ).eligible_for_removal?
      ).to be false

      photo.destroy
      expect(
        DeletedPhoto.make!(
          created_at: 1.year.ago,
          photo_id: photo,
          removed_from_s3: false
        ).eligible_for_removal?
      ).to be true
    end
  end
end
