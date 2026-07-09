# frozen_string_literal: true

class UserVirtuousTag < ApplicationRecord
  belongs_to :user
  validates_uniqueness_of :virtuous_tag, scope: :user_id

  POSSIBLE_TAGS = %w(
    MajorDonor
    MajorDonorProspect
    Foundation
    FoundationProspect
    FRU\ donors\ temporary
    Ambassador
    Do\ Not\ Contact
    Mid-Range\ Donors
  ).freeze
end
