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
  
  # Special controller routes
  
  # Users routes
  map.dashboard '/users/dashboard', :controller => 'users', :action => 'dashboard'
  
  # Resources
  # Must come after custom routes or they'll overwrite everything
  map.resources :users
  map.resource :session
  map.resources :passwords
  
  # Aliased resources
  # I vote for getting rid of this, in favor of just having 'users'
  map.resources :people, :controller => 'users'
  
  map.suspend_user '/users/:id/suspend', :controller => 'users', 
    :action => 'suspend', :requirements => { :id => %r(\d+) }
  map.unsuspend_user  '/users/:id/unsuspend', :controller => 'users', 
    :action => 'unsuspend', :requirements => { :id => %r(\d+) }
  
  #
  # Everything below here needs to be cleaned up in subsequent releases
  #
  
  map.resources :flickr_photos
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
          
  map.new_observation_batch_csv 'observations/new/batch_csv',
	        :controller => 'observations',
	        :action => 'new_batch_csv'
	        
  map.new_observation_batch 'observations/new/batch',
                :controller => 'observations',
                :action => 'new_batch'
                
  map.edit_observation_batch 'observations/edit/batch',
                 :controller => 'observations',
                 :action => 'edit_batch'
                 
  map.delete_observation_batch 'observations/delete_batch',
                 :controller => 'observations',
                 :action => 'delete_batch',
                 :conditions => {:method => :delete}
                 
  map.import_observations 'observations/import',
                 :controller => 'observations',
                 :action => 'import'
  
  map.add_marking   'observations/:id/add_marking',
                    :controller => 'observations',
                    :action => 'add_marking',
                    :conditions => {:method => :get}
                
  map.remove_marking   'observations/:id/remove_marking',
                       :controller => 'observations',
                       :action => 'remove_marking',
                       :conditions => {:method => :get}
 
  map.id_please 'observations/id_please',
                :controller => 'observations',
                :action => 'id_please',
                :conditions => {:method => :get}
                
  map.observation_selector 'observations/selector',
                :controller => 'observations',
                :action => 'selector',
                :conditions => {:method => :get}
  
  map.curate_observations '/observations/curation', :controller=>'observations', :action=>'curation'
                                        
  map.observations_by_login 'observations/:login', 
                            :controller => 'observations', 
                            :action => 'by_login',
                            :requirements => { :login => simplified_login_regex },
                            :conditions => {:method => :get}
  
  map.observations_by_login_feed 'observations/:login.:format',
                                 :controller => 'observations',
                                 :action => 'by_login',
                                 :requirements => { :login => simplified_login_regex },
                                 :conditions => {:method => :get}
  map.observation_tile_points 'observations/tile_points/:zoom/:x/:y.:format',
    :controller => 'observations',
    :action => 'tile_points',
    :requirements => { :zoom => /\d+/, :x => /\d+/, :y => /\d+/ },
    :conditions => {:method => :get}

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
  
  map.resources :comments
  
  #
  # Taxon and Name routes
  #
  map.connect 'taxa/names', :controller => 'taxon_names'
  map.connect 'taxa/names.:format', :controller => 'taxon_names'
  map.describe_taxon 'taxa/:id/description', 
                     :controller => 'taxa', :action => 'describe'
  map.graft_taxon 'taxa/:id/graft', :controller => 'taxa', :action => 'graft'
  map.taxon_children 'taxa/:id/children',
                     :controller => 'taxa', :action => 'children'
  map.formatted_taxon_children 'taxa/:id/children.:format',
                     :controller => 'taxa', :action => 'children'
  map.taxon_photos 'taxa/:id/photos',
                   :controller => 'taxa', :action => 'photos'
  map.edit_taxon_photos 'taxa/:id/edit_photos',
                   :controller => 'taxa', :action => 'edit_photos'
  map.update_taxon_photos 'taxa/:id/update_photos',
                   :controller => 'taxa', :action => 'update_photos'
  map.update_taxon_colors 'taxa/:id/update_colors',
                   :controller => 'taxa', :action => 'update_colors'
  map.flickr_tagger 'taxa/flickr_tagger', :controller => 'taxa', 
    :action => 'flickr_tagger'
  map.formatted_flickr_tagger 'taxa/flickr_tagger.:format', 
    :controller => 'taxa', 
    :action => 'flickr_tagger'
  # map.taxon_photos 'taxa/:id/photos.:format', 
  #                  :controller => 'taxa', :action => 'photos'
  map.search_taxa 'taxa/search', :controller => 'taxa', :action => 'search'
  map.formatted_search_taxa 'taxa/search.:format', :controller => 'taxa', 
    :action => 'search'
  map.resources :taxa, :requirements => { :id => %r(\d+) } do |taxon|
    taxon.resources :names, :controller => :taxon_names
    taxon.resources :flags
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
    places.formatted_place_taxa 'places/:id/taxa.:format', :action => 'taxa', :conditions => {:method => :get}
  end
  
  map.resources :flags, :requirements => { :id => %r(\d+) }
  map.admin '/admin', :controller=>'admin', :action => 'index'

  # Default route
  map.connect ':controller/:action/:id'
end
