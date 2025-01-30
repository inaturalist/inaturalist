# frozen_string_literal: true

require "spec_helper"

describe DeletedSound do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :sound }

  describe "eligible_for_removal?" do
    it "returns false if the sound is already removed" do
      expect(
        DeletedSound.make!(
          created_at: 1.year.ago
        ).eligible_for_removal?
      ).to be true
      expect(
        DeletedSound.make!(
          created_at: 1.year.ago,
          removed_from_s3: true
        ).eligible_for_removal?
      ).to be false
    end

    it "returns false if the sound is orphaned but deleted more recently than 1 month" do
      expect(
        DeletedSound.make!(
          created_at: ( 1.month - 1.day ).ago,
          orphan: true
        ).eligible_for_removal?
      ).to be false
      expect(
        DeletedSound.make!(
          created_at: ( 1.month + 1.day ).ago,
          orphan: true
        ).eligible_for_removal?
      ).to be true
    end

    it "returns false if the sound is not orphaned but deleted more recently than 6 months" do
      expect(
        DeletedSound.make!(
          created_at: ( 6.months - 1.day ).ago,
          orphan: false
        ).eligible_for_removal?
      ).to be false
      expect(
        DeletedSound.make!(
          created_at: ( 6.months + 1.day ).ago,
          orphan: false
        ).eligible_for_removal?
      ).to be true
    end

    it "returns false if the sound is set to private but deleted more recently than 2 months" do
      sound = LocalSound.make!
      ModeratorAction.create(
        action: ModeratorAction::HIDE,
        resource: sound,
        user: make_admin,
        reason: Faker::Lorem.sentence,
        private: true
      )
      sound.destroy
      expect(
        DeletedSound.make!(
          created_at: ( 2.months - 1.day ).ago,
          orphan: false,
          sound_id: sound.id
        ).eligible_for_removal?
      ).to be false
      expect(
        DeletedSound.make!(
          created_at: ( 2.months + 1.day ).ago,
          orphan: false,
          sound_id: sound.id
        ).eligible_for_removal?
      ).to be true
    end

    it "returns false if the resource still exists" do
      sound = LocalSound.make!
      expect(
        DeletedSound.make!(
          created_at: 1.year.ago,
          sound_id: sound.id,
          removed_from_s3: false
        ).eligible_for_removal?
      ).to be false

      sound.destroy
      expect(
        DeletedSound.make!(
          created_at: 1.year.ago,
          sound_id: sound,
          removed_from_s3: false
        ).eligible_for_removal?
      ).to be true
    end
  end
end
