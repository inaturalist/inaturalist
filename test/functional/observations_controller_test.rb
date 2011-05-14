require File.dirname(__FILE__) + '/../test_helper'

class ObservationsControllerTest < ActionController::TestCase
  def setup
    @o = make_observation_of_threatened
  end
  
  def test_index_finds_observations_by_taxon_name
    taxon = Taxon.make
    observation = Observation.make(:taxon => taxon)
    get :index, :format => 'json', :taxon_name => taxon.name
    assert_match /id.*?#{observation.id}/, @response.body
    assert_equal 1, assigns(:observations).map(&:taxon_id).uniq.size
  end
  
  def test_index_finds_observations_when_taxon_name_is_blank
    taxon = Taxon.make
    observation = Observation.make(:taxon => taxon)
    get :index, :format => 'json', :taxon_name => ''
    assert_match /id.*?#{observation.id}/, @response.body
  end
  
  def test_private_coordinates_hidden_for_show
    get :show, :id => @o.id
    assert_private_coordinates_hidden(@o)
  end
  
  def test_private_coordinates_hidden_for_json
    get :show, :id => @o.id, :format => "json"
    assert_private_coordinates_hidden(@o)
  end
  
  def test_private_coordinates_hidden_for_show_xml
    get :show, :id => @o.id, :format => "xml"
    assert_private_coordinates_hidden(@o)
  end
  
  def test_private_coordinates_hidden_for_index
    get :index
    assert_private_coordinates_hidden(@o)
  end
  
  def test_private_coordinates_hidden_for_index_json
    get :index, :format => "json"
    assert_private_coordinates_hidden(@o)
  end
  
  def test_private_coordinates_hidden_for_index_csv
    get :index, :format => "csv"
    assert_private_coordinates_hidden(@o)
  end
  
  def test_private_coordinates_hidden_for_by_login_csv
    get :by_login, :login => @o.user.login, :format => "csv"
    assert_private_coordinates_hidden(@o)
  end
  
  def test_private_coordinates_hidden_for_project
    p = Project.make
    p.observations << @o
    get :project, :id => p.id
    assert_private_coordinates_hidden(@o)
  end
  
  def test_private_coordinates_hidden_for_tile_points
    x, y = SPHERICAL_MERCATOR.from_ll_to_pixel([@o.longitude, @o.latitude], 5)
    x = (x / 256).floor
    y = (y / 256).floor
    get :tile_points, :format => "json", :x => x, :y => y, :zoom => 5
    assert_private_coordinates_hidden(@o)
  end
  
  def assert_private_coordinates_hidden(observation)
    assert_response :success
    assert_match /#{observation.latitude}/, @response.body
    assert_no_match /private[\-_]latitude/, @response.body
  end
end
