require File.dirname(__FILE__) + '/test_helper.rb'

load_schema

class Game < ActiveRecord::Base
  has_many :moves
  has_rules_for :moves
end

class Move < ActiveRecord::Base
  belongs_to :game
  validates_rules_from :game
  attr_accessor :bad
  attr_accessor :country
  
  def bad?
    @bad != true
  end
  
  def in_country?(country)
    @country && @country == country.name
  end
end

class Country < ActiveRecord::Base
end

class HasRulesForTest < ActiveSupport::TestCase
  
  def teardown
    purge_test_data
  end
  
  def test_game_has_rules_for_moves
    game = Game.create
    assert_equal [], game.move_rules
  end
  
  def test_move_valides_rules_from_game
    game = Game.create
    game.move_rules << Rule.new(:operator => "bad?")
    move = Move.new(:game => game, :bad => true)
    assert !move.valid?
  end
  
  def test_rule_with_operand
    game = Game.create
    spain = Country.new(:name => "Spain")
    portugal = Country.new(:name => "Portugal")
    game.move_rules << Rule.new(:operator => "in_country?", :operand => spain)
    good_move = Move.new(:game => game, :country => spain.name)
    assert good_move.valid?
    bad_move = Move.new(:game => game, :country => portugal.name)
    assert !bad_move.valid?
  end
  
end
