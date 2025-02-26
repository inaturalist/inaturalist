# frozen_string_literal: true

require "spec_helper"

describe RedirectUrl, type: :model do
  it { is_expected.to validate_presence_of :user }
  it { is_expected.to validate_presence_of :play_store_url }
  it { is_expected.to validate_presence_of :app_store_url }
end
