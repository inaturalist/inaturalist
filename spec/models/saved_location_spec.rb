# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe SavedLocation do
  it { is_expected.to belong_to(:user).inverse_of :saved_locations }
  it { is_expected.to validate_presence_of :title }
  it { is_expected.to validate_presence_of :latitude }
  it { is_expected.to validate_presence_of :longitude }
  it { is_expected.to validate_presence_of :user }
  it { is_expected.to validate_uniqueness_of(:title).scoped_to :user_id }
  it do
    is_expected.to validate_numericality_of(:latitude).is_less_than_or_equal_to(90).is_greater_than_or_equal_to -90
  end
  it do
    is_expected.to validate_numericality_of(:longitude).is_less_than_or_equal_to(180).is_greater_than_or_equal_to -180
  end
end
