require File.dirname(__FILE__) + '/../test_helper'

class ObservationsControllerTest < ActionController::TestCase
  
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
  
  def test_coordinates_obscured_for_threatened_for_show
    o = make_observation_of_threatened
    get :show, :id => o.id
    assert_private_coordinates_obscured(o)
  end
  
  def test_coordinates_obscured_for_threatened_for_json
    o = make_observation_of_threatened
    get :show, :id => o.id, :format => "json"
    assert_private_coordinates_obscured(o)
  end
  
  def test_coordinates_obscured_for_threatened_for_show_xml
    o = make_observation_of_threatened
    get :show, :id => o.id, :format => "xml"
    assert_private_coordinates_obscured(o)
  end
  
  def test_coordinates_obscured_for_threatened_for_index
    o = make_observation_of_threatened
    get :index
    assert_private_coordinates_obscured(o)
  end
  
  def test_coordinates_obscured_for_threatened_for_index_json
    o = make_observation_of_threatened
    get :index, :format => "json"
    assert_private_coordinates_obscured(o)
  end
  
  def test_coordinates_obscured_for_threatened_for_index_csv
    o = make_observation_of_threatened
    get :index, :format => "csv"
    assert_private_coordinates_obscured(o)
  end
  
  def test_coordinates_obscured_for_threatened_for_by_login_csv
    o = make_observation_of_threatened
    get :by_login, :login => o.user.login, :format => "csv"
    assert_private_coordinates_obscured(o)
  end
  
  def test_coordinates_obscured_for_threatened_for_project
    o = make_observation_of_threatened
    p = Project.make
    p.observations << o
    get :project, :id => p.id
    assert_private_coordinates_obscured(o)
  end
  
  def test_coordinates_obscured_for_threatened_for_tile_points
    o = make_observation_of_threatened
    x, y = SPHERICAL_MERCATOR.from_ll_to_pixel([o.longitude, o.latitude], 5)
    x = (x / 256).floor
    y = (y / 256).floor
    get :tile_points, :format => "json", :x => x, :y => y, :zoom => 5
    assert_private_coordinates_obscured(o)
  end
  
  # Geoprivacy
  
  def test_geoprivacy_private_hides_all_coordinates_for_show
    o = make_private_observation
    get :show, :id => o.id
    assert_private_coordinates_hidden(o)
  end
  
  def test_geoprivacy_private_hides_all_coordinates_for_show_json
    o = make_private_observation
    get :show, :id => o.id, :format => "json"
    assert_private_coordinates_hidden(o)
  end
  
  def test_geoprivacy_private_hides_all_coordinates_for_show_xml
    o = make_private_observation
    get :show, :id => o.id, :format => "xml"
    assert_private_coordinates_hidden(o)
  end
  
  def test_geoprivacy_private_hides_coordinates_for_index
    o = make_private_observation
    get :index
    assert_private_coordinates_hidden(o)
  end
  
  def test_geoprivacy_private_hides_coordinates_for_index_json
    o = make_private_observation
    get :index, :format => "json"
    assert_private_coordinates_hidden(o)
  end
  
  def test_geoprivacy_private_hides_coordinates_for_index_csv
    o = make_private_observation
    get :index, :format => "csv"
    assert_private_coordinates_hidden(o)
  end
  
  def test_geoprivacy_private_hides_coordinates_for_by_login_csv
    o = make_private_observation
    get :by_login, :login => o.user.login, :format => "csv"
    assert_private_coordinates_hidden(o)
  end
  
  def test_geoprivacy_private_hides_coordinates_for_project
    o = make_private_observation
    p = Project.make
    p.observations << o
    get :project, :id => p.id
    assert_private_coordinates_hidden(o)
  end
  
  def test_geoprivacy_private_hides_coordinates_for_tile_points
    o = make_private_observation
    x, y = SPHERICAL_MERCATOR.from_ll_to_pixel([o.private_longitude, o.private_latitude], 5)
    x = (x / 256).floor
    y = (y / 256).floor
    get :tile_points, :format => "json", :x => x, :y => y, :zoom => 5
    assert_private_coordinates_hidden(o)
  end
  
  def test_geoprivacy_obscured_obscured_coordinates_for_show
    o = Observation.make(:latitude => 38.222, :longitude => -122.333, :geoprivacy => Observation::OBSCURED)
    get :show, :id => o.id
    assert_private_coordinates_obscured(o)
  end
  # the obs spec tests whether manual obscuring really obscures, so I'm not 
  # too concerned about testing all the other endpoints here
  
  def assert_private_coordinates_obscured(observation)
    assert_response :success
    assert_match /#{observation.latitude}/, @response.body
    assert_no_match /#{observation.private_latitude}\D/, @response.body
  end
  
  def assert_private_coordinates_hidden(observation)
    assert_response :success
    assert_no_match /#{observation.private_latitude}\D/, @response.body
  end
end
