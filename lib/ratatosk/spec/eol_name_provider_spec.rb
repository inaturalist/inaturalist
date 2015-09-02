require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/name_provider_example_groups'

describe Ratatosk::NameProviders::EolNameProvider do
  it_should_behave_like "a name provider"

  before(:all) do
    load_test_taxa
    @np = Ratatosk::NameProviders::EolNameProvider.new
  end

end
