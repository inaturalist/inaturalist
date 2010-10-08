require File.dirname(__FILE__) + '/test_helper.rb'
load_schema

class RuleTest < Test::Unit::TestCase
  
  def teardown
    purge_test_data
  end
  
  def test_rule
    assert_kind_of Rule, Rule.new
  end
end