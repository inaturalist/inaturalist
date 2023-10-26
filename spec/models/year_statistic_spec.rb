require "spec_helper.rb"

describe YearStatistic do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :site }
  it { is_expected.to have_many( :year_statistic_localized_shareable_images ) }
end
