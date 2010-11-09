LOGIN_REGEX = /[A-z][A-z0-9\-_]+/
Inaturalist::Application.routes.draw do
  match '/' => 'welcome#index'
  match '/home' => 'users#dashboard', :as => :home
  match '/logout' => 'sessions#destroy', :as => :logout
  match '/login' => 'sessions#new', :as => :login
  match '/register' => 'users#create', :as => :register, :via => :post
  match '/signup' => 'users#new', :as => :signup
  match '/activate/:activation_code' => 'users#activate', :as => :activate, :activation_code => nil
  match '/forgot_password' => 'passwords#new', :as => :forgot_password
  match '/change_password/:reset_code' => 'passwords#reset', :as => :change_password
  match '/toggle_mobile' => 'welcome#toggle_mobile', :as => :toggle_mobile
  match '/help' => 'help#index', :as => :help
  match '/users/dashboard' => 'users#dashboard', :as => :dashboard
  
  resources :users
  resource :session
  resources :passwords
  resources :people, :controller => 'users'
  match '/users/:id/suspend' => 'users#suspend', :as => :suspend_user, :constraints => { :id => /\d+/ }
  match '/users/:id/unsuspend' => 'users#unsuspend', :as => :unsuspend_user, :constraints => { :id => /\d+/ }
  
  resources :photos
  match 'flickr/photos.:format' => 'flickr#photos', :via => :get
  
  match 'observations/:login' => 'observations#by_login', :as => :observations_by_login, :id => LOGIN_REGEX
  match 'observations/:login.:format' => 'observations#by_login', :as => :observations_by_login_feed, :via => :get, :login => LOGIN_REGEX
  resources :observations do
    resources :flags
  end
  match 'observations/update' => 'observations#update', :as => :update_observations
  match 'observations/new/batch_csv' => 'observations#new_batch_csv', :as => :new_observation_batch_csv
  match 'observations/new/batch' => 'observations#new_batch', :as => :new_observation_batch
  match 'observations/edit/batch' => 'observations#edit_batch', :as => :edit_observation_batch
  match 'observations/delete_batch' => 'observations#delete_batch', :as => :delete_observation_batch, :via => :delete
  match 'observations/import' => 'observations#import', :as => :import_observations
  match 'observations/import_photos' => 'observations#import_photos', :as => :import_photos
  match 'observations/id_please' => 'observations#id_please', :as => :id_please, :via => :get
  match 'observations/selector' => 'observations#selector', :as => :observation_selector, :via => :get
  match '/observations/curation' => 'observations#curation', :as => :curate_observations
  match '/observations/widget' => 'observations#widget', :as => :observations_widget
  match 'observations/add_from_list' => 'observations#add_from_list', :as => :add_observations_from_list
  match 'observations/new_from_list' => 'observations#new_from_list', :as => :new_observations_from_list
  match 'observations/nearby' => 'observations#nearby', :as => :nearby_observations
  match 'observations/add_nearby' => 'observations#add_nearby', :as => :add_nearby_observations
  match 'observations/:id/edit_photos' => 'observations#edit_photos', :as => :edit_observation_photos
  match 'observations/:id/update_photos' => 'observations#update_photos', :as => :update_observation_photos
  match 'observations/tile_points/:zoom/:x/:y.:format' => 'observations#tile_points', :as => :observation_tile_points, :via => :get, 
    :constraints => { :x => /\d+/, :y => /\d+/, :zoom => /\d+/ }
  # match 'observations/project/:id.:format' => 'observations#project', :as => :project_observations
  match 'projects/:id/observations(.:format)' => 'observations#project', :as => :project_observations
  
  resources :projects
  match 'projects/:id/join' => 'projects#join', :as => :join_project
  match 'projects/:id/leave' => 'projects#leave', :as => :leave_project
  match 'projects/:id/add' => 'projects#add', :as => :add_project_observation, :via => :post
  match 'projects/:id/remove' => 'projects#remove', :as => :remove_project_observation, :via => [:post, :delete]
  match 'projects/:id/add_batch' => 'projects#add_batch', :as => :add_project_observation_batch, :via => :post
  match 'projects/:id/remove_batch' => 'projects#remove_batch', :as => :remove_project_observation_batch, :via => [:post, :delete]
  match 'projects/search' => 'projects#search', :as => :project_search
  match 'project/:id/terms' => 'projects#terms', :as => :project_terms
  match 'projects/:login' => 'projects#by_login', :as => :projects_by_login, :login => LOGIN_REGEX
  
  match 'people/:login' => 'users#show', :as => :person_by_login, :login => LOGIN_REGEX
  match 'people/:login/followers' => 'users#relationships', :as => :followers_by_login, :login => LOGIN_REGEX, :followers => 'followers'
  match 'people/:login/following' => 'users#relationships', :as => :following_by_login, :login => LOGIN_REGEX, :following => 'following'
  
  resources :lists
  match 'lists/:id/taxa' => 'lists#taxa', :as => :list_taxa, :via => :get
  match 'lists/:id/taxa.:format' => 'lists#taxa', :as => :formatted_list_taxa, :via => :get
  resources :life_lists
  resources :check_lists
  resources :listed_taxa
  # match 'lists/:login' => 'lists#by_login', :as => :lists_by_login, :login => /\w[\w\-_]+/
  match 'lists/:login' => 'lists#by_login', :as => :lists_by_login, :login => LOGIN_REGEX
  match 'lists/:id/compare' => 'lists#compare', :as => :compare_lists
  match 'lists/:id/remove_taxon/:taxon_id' => 'lists#remove_taxon', :as => :list_remove_taxon, :via => :delete
  match 'lists/:id/add_taxon_batch' => 'lists#add_taxon_batch', :as => :list_add_taxon_batch, :via => :post
  match 'check_lists/:id/add_taxon_batch' => 'check_lists#add_taxon_batch', :as => :check_list_add_taxon_batch, :via => :post
  
  resources :comments
  
  match 'taxa/names' => 'taxon_names#index'
  match 'taxa/names.:format' => 'taxon_names#index'
  match 'taxa/:id/description' => 'taxa#describe', :as => :describe_taxon
  match 'taxa/:id/graft' => 'taxa#graft', :as => :graft_taxon
  match 'taxa/:id/children' => 'taxa#children', :as => :taxon_children
  match 'taxa/:id/children.:format' => 'taxa#children', :as => :formatted_taxon_children
  match 'taxa/:id/photos' => 'taxa#photos', :as => :taxon_photos
  match 'taxa/:id/edit_photos' => 'taxa#edit_photos', :as => :edit_taxon_photos
  match 'taxa/:id/update_photos' => 'taxa#update_photos', :as => :update_taxon_photos
  match 'taxa/:id/update_colors' => 'taxa#update_colors', :as => :update_taxon_colors
  match 'taxa/:id/add_places' => 'taxa#add_places', :as => :add_taxon_places
  match 'taxa/flickr_tagger' => 'taxa#flickr_tagger', :as => :flickr_tagger
  match 'taxa/flickr_tagger.:format' => 'taxa#flickr_tagger', :as => :formatted_flickr_tagger
  match 'taxa/search' => 'taxa#search', :as => :search_taxa
  match 'taxa/search.:format' => 'taxa#search', :as => :formatted_search_taxa
  resources :taxa do
    resources :taxon_names
    resources :flags
  end
  match 'taxa/auto_complete_name' => 'taxa#auto_complete_name'
  match 'taxa/occur_in' => 'taxa#occur_in'
  
  match 'journal' => 'posts#browse', :as => :journals
  match 'journal/:login' => 'posts#index', :as => :journal_by_login, :login => LOGIN_REGEX
  match 'journal/:login/archives/' => 'posts#archives', :as => :journal_archives, :login => LOGIN_REGEX
  match 'journal/:login/archives/:year/:month' => 'posts#archives', :as => :journal_archives_by_month, :constraints => { :month => /\d{1,2}/, :login => LOGIN_REGEX, :year => /\d{1,4}/ }
  resources :posts
  
  resources :identifications
  match 'identifications/:login' => 'identifications#by_login', :as => :identifications_by_login, :via => :get, :constraints => { :login => LOGIN_REGEX }
  match 'emailer/invite' => 'emailer#invite', :as => :emailer_invite
  match 'emailer/invite/send' => 'emailer#invite_send', :as => :emailer_invite_send, :via => :post
  
  resources :taxon_links
  
  resources :places
  match '/places/find_external' => 'places#find_external', :as => :find_external
  match '/places/search' => 'places#search', :as => :place_search, :via => :get
  match '/places/:id/children' => 'places#children', :as => :place_children, :via => :get
  match 'places/:id/taxa.:format' => 'places#taxa', :as => :place_taxa, :via => :get
  
  resources :flags
  
  match '/admin' => 'admin#index', :as => :admin
  
  match '/:controller(/:action(/:id))'
end
