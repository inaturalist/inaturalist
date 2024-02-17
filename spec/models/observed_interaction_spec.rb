# frozen_string_literal: true

require "spec_helper"

describe ObservedInteraction, type: :model do
  describe :creation do
    it "should not allow the same observation as subject and object" do
      o = create :observation
      oi = build :observed_interaction
      expect( oi ).to be_valid
      oi.subject_observation = o
      oi.object_observation = o
      expect( oi ).not_to be_valid
    end

    it "should not allow multiples with the same subject and object" do
      oi1 = create :observed_interaction
      expect( oi1 ).to be_valid
      oi2 = build :observed_interaction,
        subject_observation: oi1.subject_observation,
        object_observation: oi1.object_observation
      expect( oi2 ).not_to be_valid
    end

    it "should require an annotation" do
      oi = ObservedInteraction.new(
        subject_observation: create( :observation ),
        object_observation: create( :observation )
      )
      expect( oi ).not_to be_valid
      oi.annotations.append( make_annotation )
      expect( oi ).to be_valid
    end
  end
end
