# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe GuidePhoto, "creation" do
  elastic_models( Observation )

  it { is_expected.to validate_length_of(:description).is_at_most(256).allow_blank }
end
