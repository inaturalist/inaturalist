require 'test_helper'

class PostsControllerTest < ActionController::TestCase
  include Devise::TestHelpers
  def test_show
    o = make_observation_of_threatened
    assert !o.latitude.blank?
    assert !o.private_latitude.blank?
    p = Post.make!(:user => o.user, :parent => o.user)
    p.observations << o
    
    get :show, :id => p.id, :login => p.user.login
    assert assigns(:observations)
    
    assert_response :success
    assert_match /#{o.latitude}/, @response.body
    assert_no_match /private_latitude/, @response.body
  end
end
