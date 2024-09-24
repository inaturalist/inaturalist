# frozen_string_literal: true

require "spec_helper"

describe AnnouncementDismissal do
  it { is_expected.to belong_to :announcement }
  it { is_expected.to belong_to :user }

  it { is_expected.to validate_uniqueness_of( :user_id ).scoped_to( :announcement_id ) }
end
