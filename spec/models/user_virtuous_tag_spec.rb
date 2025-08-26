# frozen_string_literal: true

require "spec_helper"

describe UserVirtuousTag do
  it { is_expected.to belong_to( :user ) }
  it { is_expected.to validate_uniqueness_of( :virtuous_tag ).scoped_to( :user_id ) }
end
