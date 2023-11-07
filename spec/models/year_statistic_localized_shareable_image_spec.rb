require "spec_helper.rb"

describe YearStatisticLocalizedShareableImage do
  it { is_expected.to belong_to :year_statistic }
  it { is_expected.to validate_presence_of :year_statistic }
  it { is_expected.to validate_presence_of :locale }
end
