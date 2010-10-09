require File.dirname(__FILE__) + '/test_helper'

class ToCsvTest < Test::Unit::TestCase
  def setup
    @users = [
      User.new(:id => 1, :name => 'Ary', :age => 25),
      User.new(:id => 2, :name => 'Nati', :age => 22)
    ]
  end

  def test_with_empty_array
    assert_equal( "", [].to_csv )
  end

  def test_with_no_options
    assert_equal( "Age,Id,Name\n25,1,Ary\n22,2,Nati\n", @users.to_csv )
  end

  def test_with_no_headers
    assert_equal( "25,1,Ary\n22,2,Nati\n", @users.to_csv(:headers => false) )
  end

  def test_with_only
    assert_equal( "Name\nAry\nNati\n", @users.to_csv(:only => :name) )
  end

  def test_with_empty_only
    assert_equal( "", @users.to_csv(:only => "") )
  end

  def test_with_only_and_wrong_column_names
    assert_equal( "Name\nAry\nNati\n", @users.to_csv(:only => [:name, :yoyo]) )
  end

  def test_with_except
    assert_equal( "Age\n25\n22\n", @users.to_csv(:except => [:id, :name]) )
  end

  def test_with_except_and_only_should_listen_to_only
    assert_equal( "Name\nAry\nNati\n", @users.to_csv(:except => [:id, :name], :only => :name) )
  end

  def test_with_except
    assert_equal( "Age,Id,Name,Is old?\n25,1,Ary,false\n22,2,Nati,false\n", @users.to_csv(:methods => [:is_old?]) )
  end
end
