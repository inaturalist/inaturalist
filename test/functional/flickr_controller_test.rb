require File.dirname(__FILE__) + '/../test_helper'

class FlickrControllerTest < ActionController::TestCase
  # Replace this with your real tests.
  def test_that_link_page_renders
    get :link
    assert_response :success
  end
  
  def test_that_authorize_page_doesnt_render_without_frob
    get :authorize
    assert_response :redirect
  end
  
  def test_that_authorize_page_doesnt_redirect_with_frob_but_throws_error_on_invalid_frob
    assert_raise Net::Flickr::APIError do
      get :authorize, {:frob => '1234abcd'}
    end
  end
end
