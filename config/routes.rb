ActionController::Routing::Routes.draw do |map|
  simplified_login_regex = /\w[\w\-_]+/
  
  map.root :controller => 'welcome', :action => 'index'
  
  # Top level routes
  # Anything that violates the /:controller first route standard goes here
  map.home '/home', :controller => 'users', :action => 'dashboard'
  map.logout '/logout', :controller => 'sessions', :action => 'destroy'
  map.login '/login', :controller => 'sessions', :action => 'new'
  map.register '/register', :controller => 'users', :action => 'create', :conditions => {:method => :post}
  map.signup '/signup', :controller => 'users', :action => 'new'
  map.activate '/activate/:activation_code', :controller => 'users', :action => 'activate', :activation_code => nil
  map.forgot_password '/forgot_password', :controller => 'passwords', :action => 'new'
  map.change_password '/change_password/:reset_code', :controller => 'passwords', :action => 'reset'
  map.toggle_mobile "/toggle_mobile", :controller => 'welcome', :action => 'toggle_mobile'
  
  map.help '/help', :controller => 'help'
  
  # Special controller routes
  
  # Users routes
  map.with_options(:controller => 'users') do |users|
    users.dashboard '/users/dashboard', :action => 'dashboard'
    users.curate_users '/users/curation', :action => 'curation'
  end
  
  # Resources
  # Must come after custom routes or they'll overwrite everything
  map.resources :users
  map.resource :session
  map.resources :passwords
  
  # Aliased resources
  # I vote for getting rid of this, in favor of just having 'users'
  map.resources :people, :controller => 'users'
  
  map.with_options :controller => "users", :requirements => { :id => %r(\d+) } do |u|
    u.suspend_user '/users/:id/suspend', :action => 'suspend'
    u.unsuspend_user '/users/:id/unsuspend', :action => 'unsuspend'
    u.add_role 'users/:id/add_role', :action => 'add_role', :method => :post
    u.remove_role 'users/:id/remove_role', :action => 'remove_role', :method => :delete
  end
  
  #
  # Everything below here needs to be cleaned up in subsequent releases
  #
  
  map.resources :photos, :only => :show
  map.resources :observation_photos, :only => :create
  map.connect   'flickr/photos.:format',
                :controller => 'flickr',
                :action => 'photos',
                :conditions => {:method => :get}

  # /observations/                # all observations
  # /observation/new              # new obs (though index will probably be the main interface for this)
  # /observations/212445          # single observation
  # /observations/212445/edit     # edit an observation
  # /observations/kueda/          # kueda's observations  
  map.resources :observations, :requirements => { :id => %r(\d+) } do |observation|
    observation.resources :flags
  end
  
  map.with_options :controller => "observations" do |o|
    o.update_observations 'observations/update', :action => 'update'
    o.new_observation_batch_csv 'observations/new/batch_csv', :action => 'new_batch_csv'
    o.new_observation_batch 'observations/new/batch', :action => 'new_batch'
    o.edit_observation_batch 'observations/edit/batch', :action => 'edit_batch'
    o.delete_observation_batch 'observations/delete_batch', :action => 'delete_batch',
      :conditions => {:method => :delete}
    o.import_observations 'observations/import', :action => 'import'
    o.import_photos 'observations/import_photos', :action => 'import_photos'
    o.id_please 'observations/id_please', :action => 'id_please',
      :conditions => {:method => :get}
    o.observation_selector 'observations/selector', :action => 'selector',
      :conditions => {:method => :get}
    o.curate_observations '/observations/curation', :action => 'curation'
    o.observations_widget '/observations/widget', :action => 'widget'
    o.add_observations_from_list "observations/add_from_list", :action => "add_from_list"
    o.new_observations_from_list "observations/new_from_list", :action => "new_from_list"
    o.nearby_observations "observations/nearby", :action => "nearby"
    o.add_nearby_observations "observations/add_nearby", :action => "add_nearby"
    o.edit_observation_photos "observations/:id/edit_photos", :action => "edit_photos"
    o.update_observation_photos "observations/:id/update_photos", :action => "update_photos"
    
    # by_login paths must come after all others
    o.observations_by_login 'observations/:login', :action => 'by_login',
      :requirements => { :login => simplified_login_regex }
    o.observations_by_login_feed 'observations/:login.:format', :action => 'by_login',
      :requirements => { :login => simplified_login_regex },
      :conditions => {:method => :get}
    o.observation_tile_points 'observations/tile_points/:zoom/:x/:y.:format', :action => 'tile_points',
      :requirements => { :zoom => /\d+/, :x => /\d+/, :y => /\d+/ },
      :conditions => {:method => :get}
    o.project_observations 'observations/project/:id.:format', :action => "project"
  end
  
  map.resources :projects, :requirements => { :id => %r(\d+) }
  map.with_options :controller => "projects" do |p|
    p.join_project "projects/:id/join", :action => "join"
    p.leave_project "projects/:id/leave", :action => "leave"
    p.add_project_observation "projects/:id/add", :action => "add",
      :conditions => {:method => :post}
    p.remove_project_observation "projects/:id/remove", :action => "remove",
      :conditions => {:method => [:post, :delete]}
    p.add_project_observation_batch "projects/:id/add_batch", :action => "add_batch",
      :conditions => {:method => :post}
    p.remove_project_observation_batch "projects/:id/remove_batch", :action => "remove_batch",
      :conditions => {:method => [:post, :delete]}
    p.project_search 'projects/search', :action => "search"
    p.project_terms "project/:id/terms", :action => "terms"
    p.projects_by_login 'projects/:login', :action => 'by_login',
      :requirements => { :login => simplified_login_regex }
    p.project_members "projects/:id/members", :action => "members"
    p.project_contributors "projects/:id/contributors", :action => "contributors"
    p.formatted_project_contributors "projects/:id/contributors.:format", :action => "contributors"
    p.project_species_count "projects/:id/species_count", :action => "species_count"
    p.formatted_project_species_count "projects/:id/species_count.:format", :action => "species_count"
    p.project_show_contributor "projects/:id/contributors/:project_user_id", :action => "show_contributor"
    p.project_map 'projects/:id/map', :action => 'map'
    p.make_curator 'projects/:id/make_curator/:project_user_id', :action => 'make_curator'
    p.remove_curator 'projects/:id/remove_curator/:project_user_id', :action => 'remove_curator'
  end
  
  map.resources :project_assets, :except => [:index, :show]
  map.resources :custom_projects, :except => [:index, :show]
  
  map.person_by_login 'people/:login', 
                      :controller => 'users',
                      :action => 'show',
                      :requirements => { :login => simplified_login_regex }
                      
  map.followers_by_login 'people/:login/followers', 
                      :controller => 'users',
                      :action => 'relationships',
                      :followers => 'followers',
                      :requirements => { :login => simplified_login_regex }
                      
  map.following_by_login 'people/:login/following', 
                      :controller => 'users',
                      :action => 'relationships',
                      :following => 'following',
                      :requirements => { :login => simplified_login_regex }                      

  map.resources :lists, :requirements => { :id => %r(\d+) }
  map.with_options :controller => 'lists' do |lists|
    lists.list_taxa 'lists/:id/taxa', :action => 'taxa', :conditions => {:method => :get}
    lists.formatted_list_taxa 'lists/:id/taxa.:format', :action => 'taxa', :conditions => {:method => :get}
  end
  map.resources :life_lists, :controller => 'lists'
  map.resources :check_lists
  map.resources :project_lists, :controller => 'lists'
  map.resources :listed_taxa
  
  map.lists_by_login 'lists/:login', :controller => 'lists', 
                                     :action => 'by_login',
                                     :requirements => { :login => simplified_login_regex }
  map.compare_lists 'lists/:id/compare', :controller => 'lists', :action => 'compare'
  map.list_remove_taxon 'lists/:id/remove_taxon/:taxon_id', 
    :controller => 'lists', 
    :action => 'remove_taxon',
    :conditions => {:method => :delete}
  map.list_add_taxon_batch 'lists/:id/add_taxon_batch', 
    :controller => 'lists', 
    :action => 'add_taxon_batch',
    :conditions => {:method => :post}
  map.check_list_add_taxon_batch 'check_lists/:id/add_taxon_batch', 
    :controller => 'check_lists', 
    :action => 'add_taxon_batch',
    :conditions => {:method => :post}
  map.list_reload_from_observations 'lists/:id/reload_from_observations', 
    :controller => 'lists', :action => 'reload_from_observations'
  
  map.resources :comments
  
  #
  # Taxon and Name routes
  #
  map.connect 'taxa/names', :controller => 'taxon_names'
  map.connect 'taxa/names.:format', :controller => 'taxon_names'
  map.resources :taxa, :requirements => { :id => %r(\d+) } do |taxon|
    # taxon.resources :names, :controller => :taxon_names
    taxon.resources :taxon_names, :controller => :taxon_names, :shallow => true
    taxon.resources :flags
  end
  map.with_options :controller => 'taxa' do |taxa|
    taxa.describe_taxon 'taxa/:id/description', :action => 'describe'
    taxa.graft_taxon 'taxa/:id/graft', :action => 'graft'
    taxa.taxon_children 'taxa/:id/children', :action => 'children'
    taxa.formatted_taxon_children 'taxa/:id/children.:format', :action => 'children'
    taxa.taxon_photos 'taxa/:id/photos', :action => 'photos'
    taxa.edit_taxon_photos 'taxa/:id/edit_photos', :action => 'edit_photos'
    taxa.update_taxon_photos 'taxa/:id/update_photos', :action => 'update_photos'
    taxa.update_taxon_colors 'taxa/:id/update_colors', :action => 'update_colors'
    taxa.add_taxon_places 'taxa/:id/add_places', :action => 'add_places'
    taxa.flickr_tagger 'taxa/flickr_tagger', :action => 'flickr_tagger'
    taxa.formatted_flickr_tagger 'taxa/flickr_tagger.:format', :action => 'flickr_tagger'
    taxa.search_taxa 'taxa/search', :action => 'search'
    taxa.formatted_search_taxa 'taxa/search.:format', :action => 'search'
    taxa.formatted_taxa_action 'taxa/:action.:format'
    taxa.merge_taxon 'taxa/:id/merge', :action => 'merge'
    taxa.formatted_merge_taxon 'taxa/:id/merge.:format', :action => 'merge'
  end
  
  map.connect 'taxa/auto_complete_name', :controller => 'taxa',
                                         :action => 'auto_complete_name'

  map.connect 'taxa/occur_in', :controller => 'taxa',
                               :action => 'occur_in'
  
  #
  # Sources
  #        
  # map.resources :sources
  
  # Posts and journals
  map.journals 'journal', :controller => 'posts', :action => 'browse'
  map.journal_by_login 'journal/:login', 
    :controller => 'posts',
    :action => 'index',
    :requirements => { :login => simplified_login_regex }
  map.journal_archives 'journal/:login/archives/', 
    :controller => 'posts',
    :action => 'archives',
    :requirements => { :login => simplified_login_regex }
  map.journal_archives_by_month 'journal/:login/archives/:year/:month', 
    :controller => 'posts',
    :action => 'archives',
    :requirements => {
      :login => simplified_login_regex,
      :year => /\d{1,4}/,
      :month => /\d{1,2}/
    }
  map.resources :posts, :controller => 'posts', 
    :path_prefix => "/journal/:login",
    :requirements => { :login => simplified_login_regex }
  
  map.resources :identifications, :requirements => { :id => %r(\d+) }
  map.identifications_by_login 'identifications/:login', 
    :controller => 'identifications',
    :action => 'by_login',
    :conditions => { :method => :get },
    :requirements => { :login => simplified_login_regex }

  map.emailer_invite 'emailer/invite', :controller => 'emailer', :action => 'invite'
  map.emailer_invite_send 'emailer/invite/send', :controller => 'emailer', :action =>'invite_send', :conditions => {:method => :post}
  
  map.resources :taxon_links, :except => [:show, :index],
    :requirements => { :id => %r(\d+) }
  
  map.resources :places, :requirements => { :id => %r(\d+) }
  map.with_options :controller => 'places' do |places|
    places.find_external '/places/find_external', :action => 'find_external'
    places.place_search '/places/search', :action => 'search', :conditions => {:method => :get}
    places.place_children '/places/:id/children', :action => 'children', :conditions => {:method => :get}
    places.place_taxa 'places/:id/taxa.:format', :action => 'taxa', :conditions => {:method => :get}
    places.place_geometry 'places/geometry/:id.:format', :action => 'geometry', :conditions => {:method => :get}
  end
  
  map.resources :flags, :requirements => { :id => %r(\d+) }
  map.admin '/admin', :controller => 'admin', :action => 'index'
  map.resources :taxon_ranges, :except => [:index, :show]

  # Default route
  map.connect ':controller/:action/:id'
end
