# require 'test_helper'
require File.expand_path(File.dirname(__FILE__) + "/../test_helper")

class ObservationsControllerTest < ActionController::TestCase
  include Devise::TestHelpers
  
  def test_index_finds_observations_by_taxon_name
    taxon = Taxon.make!
    observation = Observation.make!(:taxon => taxon)
    get :index, :format => :json, :taxon_name => taxon.name
    assert_match /id.*?#{observation.id}/, @response.body
    assert_equal 1, assigns(:observations).map(&:taxon_id).uniq.size
  end
  
  def test_index_finds_observations_when_taxon_name_is_blank
    taxon = Taxon.make!
    observation = Observation.make!(:taxon => taxon)
    get :index, :format => :json, :taxon_name => ''
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
    p = Project.make!
    pu = ProjectUser.make!(:project => p)
    o = make_observation_of_threatened(:user => pu.user)
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
    p = Project.make!
    pu = ProjectUser.make!(:project => p)
    o = make_private_observation(:user => pu.user)
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
    o = Observation.make!(:latitude => 38.222, :longitude => -122.333, :geoprivacy => Observation::OBSCURED)
    get :show, :id => o.id
    assert_private_coordinates_obscured(o)
  end
  # the obs spec tests whether manual obscuring really obscures, so I'm not 
  # too concerned about testing all the other endpoints here

  def test_csv_download_under_1000
    o = Observation.make!(:species_guess => 'flubbernutter')
    sign_in o.user
    get :by_login_all, :login => o.user.login, :format => "csv"
    assert_response :success
    assert_match /flubbernutter/, @response.body
  end

  def test_no_user_agent_in_csv
    o = Observation.make!(:user_agent => 'flubbernutter')
    get :index, :format => "csv"
    assert_response :success
    assert_no_match /flubbernutter/, @response.body
  end

  def test_index_coordinates_visible_for_owner
    t = Taxon.make!
    o = Observation.make!(:latitude => 38.52345, :longitude => -122.345435, :geoprivacy => Observation::OBSCURED, :taxon => t)
    assert !o.private_latitude.blank?
    sign_in o.user
    get :index, :taxon_id => t.id
    assert_coordinates_visible(o)
  end
  
  def assert_private_coordinates_obscured(observation)
    assert_response :success
    assert_match /#{observation.latitude}/, @response.body
    assert_no_match /#{observation.private_latitude}\D/, @response.body
  end
  
  def assert_private_coordinates_hidden(observation)
    assert_response :success
    assert_no_match /#{observation.private_latitude}\D/, @response.body
  end

  def assert_coordinates_visible(observation)
    assert_response :success
    if observation.private_latitude
      assert_match /#{observation.private_latitude}/, @response.body
    else
      assert_match /#{observation.latitude}/, @response.body
    end
  end
end
