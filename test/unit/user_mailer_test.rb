require File.dirname(__FILE__) + '/../test_helper'

class UserMailerTest < ActionMailer::TestCase
  tests UserMailer
  fixtures :users
  
  def test_activation
    mail = UserMailer.deliver_activation(users(:quentin))
  end
end