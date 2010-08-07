require File.dirname(__FILE__) + '/test_helper.rb'

load_schema
class Game < ActiveRecord::Base; end
class Move < ActiveRecord::Base; end

class RulerTest < ActiveSupport::TestCase
  
  def test_schema_loaded
    assert_equal [], Game.all
    assert_equal [], Move.all
  end
  
  def teardown
    purge_test_data
  end
end