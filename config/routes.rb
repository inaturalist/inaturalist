# Inaturalist::Application.routes.draw do
Rails.application.routes.draw do
  resources :guide_users


  apipie

  resources :sites


  id_param_pattern = %r(\d+([\w\-\%]*))
  simplified_login_regex = /\w[^\.,\/]+/  
  root :to => 'welcome#index'
  
  resources :guide_sections do
    collection do
      get :import
    end
  end
  resources :guide_ranges do
    collection do
      get :import
    end
  end
  resources :guide_photos
  resources :guide_taxa do
    member do
      get :edit_photos
      post :update_photos
      post :sync
    end
  end
  resources :guides do
    collection do
      get :search
      get :user
    end
    member do
      post :import_taxa
      put :reorder
      put :add_color_tags
      put "add_tags_for_rank/:rank" => "guides#add_tags_for_rank"
      put :remove_all_tags
    end
    resources :flags
  end
  match '/guides/:id.:layout.pdf' => 'guides#show', :via => :get, :as => "guide_pdf", :constraints => {:format => :pdf}, :defaults => {:format => :pdf}
  match 'guides/user/:login' => 'guides#user', :as => :guides_by_login, :constraints => { :login => simplified_login_regex }


  resources :messages, :except => [:edit, :update] do
    collection do
      get :count
      get :new_messages
    end
  end

  match '/oauth/assertion_token' => 'provider_oauth#assertion', :via => :post
  match '/oauth/bounce' => 'provider_oauth#bounce', :as => "oauth_bounce"
  match '/oauth/bounce_back' => 'provider_oauth#bounce_back', :as => "oauth_bounce_back"
  use_doorkeeper do
    controllers :applications => 'oauth_applications',
                :authorizations => 'oauth_authorizations'
  end

  wiki_root '/pages'

  # Riparian routes
  resources :flow_tasks do
    member do
      get :run
    end
  end

  resources :observation_field_values, :only => [:create, :update, :destroy, :index]
  resources :observation_fields do
    member do
      get :merge
      put :merge, :to => 'observation_fields#merge_field'
    end
  end
  match '/' => 'welcome#index'
  match '/home' => 'users#dashboard', :as => :home
  match '/home.:format' => 'users#dashboard', :as => :formatted_home
  
  match '/users/edit' => 'users#edit', :as => "generic_edit_user"
  devise_for :users, :controllers => {:sessions => 'users/sessions', :registrations => 'users/registrations'}
  devise_scope :user do
    get "login", :to => "users/sessions#new"
    get "logout", :to => "users/sessions#destroy"
    post "session", :to => "users/sessions#create", :as => "user_session"
    get "signup", :to => "users/registrations#new"
    get "users/new", :to => "users/registrations#new", :as => "new_user"
    get "/forgot_password", :to => "devise/passwords#new", :as => "forgot_password"
    put "users/update_session", :to => "users#update_session"
  end
  
  match '/activate/:activation_code' => 'users#activate', :as => :activate, :activation_code => nil
  match '/toggle_mobile' => 'welcome#toggle_mobile', :as => :toggle_mobile
  match '/help' => 'help#index', :as => :help
  match '/auth/failure' => 'provider_authorizations#failure', :as => :omniauth_failure
  match '/auth/:provider' => 'provider_authorizations#blank'
  match '/auth/:provider/callback' => 'provider_authorizations#create', :as => :omniauth_callback
  match '/auth/:provider/disconnect' => 'provider_authorizations#destroy', :as => :omniauth_disconnect, :method => 'delete'
  match '/users/edit_after_auth' => 'users#edit_after_auth', :as => :edit_after_auth
  match '/facebook/photo_fields' => 'facebook#photo_fields'
  match "/eol/photo_fields" => "eol#photo_fields"
  match '/wikimedia_commons/photo_fields' => 'wikimedia_commons#photo_fields'
  
  match '/flickr/invite' => 'photos#invite', :as => :flickr_accept_invite
  match '/facebook/invite' => 'photos#invite', :as => :fb_accept_invite
  match '/picasa/invite' => 'photos#invite', :as => :picasa_accept_invite

  match "/photos/inviter" => "photos#inviter", :as => :photo_inviter
  resources :announcements
  match '/users/dashboard' => 'users#dashboard', :as => :dashboard
  match '/users/curation' => 'users#curation', :as => :curate_users
  match '/users/updates_count' => 'users#updates_count', :as => :updates_count
  match '/users/new_updates' => 'users#new_updates', :as => :new_updates
  
  resources :users, :except => [:new, :create]
  # resource :session
  # resources :passwords
  resources :people, :controller => :users, :except => [:create] do
    collection do
      get :search
      get 'leaderboard(/:year(/:month))' => :leaderboard, :as => 'leaderboard_for'
    end
  end
  match '/users/:id/suspend' => 'users#suspend', :as => :suspend_user, :constraints => { :id => /\d+/ }
  match '/users/:id/unsuspend' => 'users#unsuspend', :as => :unsuspend_user, :constraints => { :id => /\d+/ }
  match 'users/:id/add_role' => 'users#add_role', :as => :add_role, :constraints => { :id => /\d+/ }, :method => :post
  match 'users/:id/remove_role' => 'users#remove_role', :as => :remove_role, :constraints => { :id => /\d+/ }, :method => :delete
  match 'photos/local_photo_fields' => 'photos#local_photo_fields', :as => :local_photo_fields
  match '/photos/:id/repair' => "photos#repair", :as => :photo_repair, :via => :put
  resources :photos, :only => [:show, :update, :destroy] do
    resources :flags
    member do
      put :rotate
    end
  end
  match 'picasa/unlink' => 'picasa#unlink', :method => :delete

  resources :observation_photos, :only => [:show, :create, :update, :destroy]
  match 'flickr/photos.:format' => 'flickr#photos', :via => :get
  resources :soundcloud_sounds, :only => [:index]
  resources :observations, :constraints => { :id => id_param_pattern } do
    resources :flags
    get 'fields', :as => 'extra_fields'
    get 'community_taxon_summary'
    collection do
      get :upload
      post :photo
      get :stats
      get :taxa
      get :taxon_stats
      get :user_stats
      get :accumulation
      get :phylogram
      get :export
      post :email_export
      get :map
    end
    member do
      put :viewed_updates
      put :update_fields
    end
  end

  match 'observations/identotron' => 'observations#identotron', :as => :identotron
  match 'observations/update' => 'observations#update', :as => :update_observations
  match 'observations/new/batch_csv' => 'observations#new_batch_csv', :as => :new_observation_batch_csv
  match 'observations/new/batch' => 'observations#new_batch', :as => :new_observation_batch
  match 'observations/new/bulk_csv' => 'observations#new_bulk_csv', :as => :new_observation_bulk_csv
  match 'observations/edit/batch' => 'observations#edit_batch', :as => :edit_observation_batch
  match 'observations/delete_batch' => 'observations#delete_batch', :as => :delete_observation_batch, :via => :delete
  match 'observations/import' => 'observations#import', :as => :import_observations
  match 'observations/import_photos' => 'observations#import_photos', :as => :import_photos
  post 'observations/import_sounds' => 'observations#import_sounds', :as => :import_sounds
  match 'observations/id_please' => 'observations#id_please', :as => :id_please, :via => :get
  match 'observations/selector' => 'observations#selector', :as => :observation_selector, :via => :get
  match '/observations/curation' => 'observations#curation', :as => :curate_observations
  match '/observations/widget' => 'observations#widget', :as => :observations_widget
  match 'observations/add_from_list' => 'observations#add_from_list', :as => :add_observations_from_list
  match 'observations/new_from_list' => 'observations#new_from_list', :as => :new_observations_from_list
  match 'observations/nearby' => 'observations#nearby', :as => :nearby_observations
  match 'observations/add_nearby' => 'observations#add_nearby', :as => :add_nearby_observations
  match 'observations/:id/edit_photos' => 'observations#edit_photos', :as => :edit_observation_photos
  match 'observations/:id/update_photos' => 'observations#update_photos', :as => :update_observation_photos, :via => :post
  match 'observations/:login' => 'observations#by_login', :as => :observations_by_login, :constraints => { :login => simplified_login_regex }
  match 'observations/:login.all' => 'observations#by_login_all', :as => :observations_by_login_all, :constraints => { :login => simplified_login_regex }
  match 'observations/:login.:format' => 'observations#by_login', :as => :observations_by_login_feed, :constraints => { :login => simplified_login_regex }, :via => :get
  match 'observations/tile_points/:zoom/:x/:y.:format' => 'observations#tile_points', :as => :observation_tile_points, :constraints => { :zoom => /\d+/, :y => /\d+/, :x => /\d+/ }, :via => :get
  match 'observations/project/:id' => 'observations#project', :as => :project_observations
  match 'observations/project/:id.all' => 'observations#project_all', :as => :all_project_observations
  match 'observations/of/:id.:format' => 'observations#of', :as => :observations_of
  match 'observations/:id/quality/:metric' => 'quality_metrics#vote', :as => :observation_quality, :via => [:post, :delete]
  match 'projects/:id/join' => 'projects#join', :as => :join_project
  match 'projects/:id/leave' => 'projects#leave', :as => :leave_project
  match 'projects/:id/add' => 'projects#add', :as => :add_project_observation, :via => :post
  match 'projects/:id/remove' => 'projects#remove', :as => :remove_project_observation, :via => [:post, :delete]
  match 'projects/:id/add_batch' => 'projects#add_batch', :as => :add_project_observation_batch, :via => :post
  match 'projects/:id/remove_batch' => 'projects#remove_batch', :as => :remove_project_observation_batch, :via => [:post, :delete]
  match 'projects/search' => 'projects#search', :as => :project_search
  match 'projects/search.:format' => 'projects#search', :as => :formatted_project_search
  match 'project/:id/terms' => 'projects#terms', :as => :project_terms
  match 'projects/user/:login' => 'projects#by_login', :as => :projects_by_login, :constraints => { :login => simplified_login_regex }
  match 'projects/:id/members' => 'projects#members', :as => :project_members
  match 'projects/:id/bulk_template' => 'projects#bulk_template', :as => :project_bulk_template
  match 'projects/:id/contributors' => 'projects#contributors', :as => :project_contributors
  match 'projects/:id/contributors.:format' => 'projects#contributors', :as => :formatted_project_contributors
  match 'projects/:id/observed_taxa_count' => 'projects#observed_taxa_count', :as => :project_observed_taxa_count
  match 'projects/:id/observed_taxa_count.:format' => 'projects#observed_taxa_count', :as => :formatted_project_observed_taxa_count
  match 'projects/:id/species_count.:format' => 'projects#observed_taxa_count', :as => :formatted_project_species_count
  match 'projects/:id/contributors/:project_user_id' => 'projects#show_contributor', :as => :project_show_contributor
  match 'projects/:id/make_curator/:project_user_id' => 'projects#make_curator', :as => :make_curator
  match 'projects/:id/remove_curator/:project_user_id' => 'projects#remove_curator', :as => :remove_curator
  match 'projects/:id/remove_project_user/:project_user_id' => 'projects#remove_project_user', :as => :remove_project_user
  match 'projects/:id/change_role/:project_user_id' => 'projects#change_role', :as => :change_project_user_role, :via => :post
  match 'projects/:id/stats' => 'projects#stats', :as => :project_stats
  match 'projects/:id/stats.:format' => 'projects#stats', :as => :formatted_project_stats
  match 'projects/browse' => 'projects#browse', :as => :browse_projects
  match 'projects/:id/invitations' => 'projects#invitations', :as => :invitations
  match 'projects/:project_id/journal/new' => 'posts#new', :as => :new_project_journal_post
  match 'projects/:project_id/journal' => 'posts#index', :as => :project_journal
  match 'projects/:project_id/journal/:id' => 'posts#show', :as => :project_journal_post, :via => :get
  match 'projects/:project_id/journal/:id' => 'posts#destroy', :as => :delete_project_journal_post, :via => :delete
  match 'projects/:project_id/journal/:id/edit' => 'posts#edit', :as => :edit_project_journal_post
  match 'projects/:project_id/journal/archives/:year/:month' => 'posts#archives', :as => :project_journal_archives_by_month, :constraints => { :month => /\d{1,2}/, :year => /\d{1,4}/ }

  resources :assessment_sections, :only => [:show] 
  resources :assessments, :only => [:new, :create, :show, :edit, :update, :destroy] do
    resources :assessment_sections, :only => [:new, :create, :show, :edit, :update] 
  end

  resources :projects do
    member do
      post :add_matching, :as => :add_matching_to
      get :preview_matching, :as => :preview_matching_for
      get :invite, :as => :invite_to
    end
    resources :flags
    resources :assessments, :only => [:new, :create, :show, :index, :edit, :update]
  end

  resources :project_assets, :except => [:index, :show]
  resources :project_observations, :only => [:create, :destroy]
  resources :custom_projects, :except => [:index, :show]
  resources :project_user_invitations, :only => [:create, :destroy]

  match 'people/:login' => 'users#show', :as => :person_by_login, :constraints => { :login => simplified_login_regex }
  match 'people/:login/followers' => 'users#relationships', :as => :followers_by_login, :constraints => { :login => simplified_login_regex }, :followers => 'followers'
  match 'people/:login/following' => 'users#relationships', :as => :following_by_login, :constraints => { :login => simplified_login_regex }, :following => 'following'
  resources :lists, :constraints => { :id => id_param_pattern } do
    resources :flags
    get 'batch_edit'
  end
  match 'lists/:id/taxa' => 'lists#taxa', :as => :list_taxa, :via => :get
  match 'lists/:id/taxa.:format' => 'lists#taxa', :as => :formatted_list_taxa, :via => :get
  match 'lists/:id.:view_type.:format' => 'lists#show',
    :as => 'list_show_formatted_view',
    :requirements => { :id => id_param_pattern }
  resources :life_lists, :controller => :lists do
    resources :flags
  end
  resources :check_lists
  resources :project_lists, :controller => :lists
  resources :listed_taxa
  match 'lists/:login' => 'lists#by_login', :as => :lists_by_login, :constraints => { :login => simplified_login_regex }
  match 'lists/:id/compare' => 'lists#compare', :as => :compare_lists, :constraints => { :id => /\d+([\w\-\%]*)/ }
  match 'lists/:id/remove_taxon/:taxon_id' => 'lists#remove_taxon', :as => :list_remove_taxon, :constraints => { :id => /\d+([\w\-\%]*)/ }, :via => :delete
  match 'lists/:id/add_taxon_batch' => 'lists#add_taxon_batch', :as => :list_add_taxon_batch, :constraints => { :id => /\d+([\w\-\%]*)/ }, :via => :post
  match 'check_lists/:id/add_taxon_batch' => 'check_lists#add_taxon_batch', :as => :check_list_add_taxon_batch, :constraints => { :id => /\d+([\w\-\%]*)/ }, :via => :post
  match 'lists/:id/reload_from_observations' => 'lists#reload_from_observations', :as => :list_reload_from_observations, :constraints => { :id => /\d+([\w\-\%]*)/ }
  match 'lists/:id/reload_and_refresh_now' => 'lists#reload_and_refresh_now', :as => :list_reload_and_refresh_now, :constraints => { :id => /\d+([\w\-\%]*)/ }
  match 'lists/:id/refresh_now_without_reload' => 'lists#refresh_now_without_reload', :as => :list_refresh_now_without_reload, :constraints => { :id => /\d+([\w\-\%]*)/ }
  match 'lists/:id/refresh' => 'lists#refresh', :as => :list_refresh, :constraints => { :id => /\d+([\w\-\%]*)/ }
  match 'lists/:id/add_from_observations_now' => 'lists#add_from_observations_now', :as => :list_add_from_observations_now, :constraints => { :id => /\d+([\w\-\%]*)/ }
  match 'lists/:id/refresh_now' => 'lists#refresh_now', :as => :list_refresh_now, :constraints => { :id => /\d+([\w\-\%]*)/ }
  match 'lists/:id/generate_csv' => 'lists#generate_csv', :as => :list_generate_csv, :constraints => { :id => /\d+([\w\-\%]*)/ }
  resources :comments do
    resources :flags
  end
  match 'comments/user/:login' => 'comments#user', :as => :comments_by_login, :constraints => { :login => simplified_login_regex }
  resources :project_invitations, :except => [:index, :show]
  match 'project_invitation/:id/accept' => 'project_invitations#accept', :as => :accept_project_invitation, :via => :post
  match 'taxa/names' => 'taxon_names#index'
  resources :taxa, :constraints => { :id => id_param_pattern } do
    resources :flags
    resources :taxon_names, :controller => :taxon_names, :shallow => true
    resources :taxon_scheme_taxa, :controller => :taxon_scheme_taxa, :shallow => true
    get 'description' => 'taxa#describe', :on => :member, :as => :describe
    member do
      post 'update_photos', :as => "update_photos_for"
      post 'refresh_wikipedia_summary', :as => "refresh_wikipedia_summary_for"
      get 'schemes', :as => "schemes_for", :constraints => {:format => [:html, :mobile]}
      get 'tip'
      get 'names', :to => 'taxon_names#taxon'
    end
    collection do
      get 'tree'
      get 'synonyms'
    end
  end
  resources :taxon_names do
    member do
      delete :destroy_synonyms, :as => 'delete_synonyms_of'
    end
  end
  # match 'taxa/:id/description' => 'taxa#describe', :as => :describe_taxon
  match 'taxa/:id/graft' => 'taxa#graft', :as => :graft_taxon
  match 'taxa/:id/children' => 'taxa#children', :as => :taxon_children
  match 'taxa/:id/children.:format' => 'taxa#children', :as => :formatted_taxon_children
  match 'taxa/:id/photos' => 'taxa#photos', :as => :taxon_photos
  match 'taxa/:id/edit_photos' => 'taxa#edit_photos', :as => :edit_taxon_photos
  match 'taxa/:id/update_colors' => 'taxa#update_colors', :as => :update_taxon_colors, :via => :put
  match 'taxa/:id/add_places' => 'taxa#add_places', :as => :add_taxon_places
  match 'taxa/flickr_tagger' => 'taxa#flickr_tagger', :as => :flickr_tagger
  match 'taxa/flickr_tagger.:format' => 'taxa#flickr_tagger', :as => :formatted_flickr_tagger
  match 'taxa/tag_flickr_photos', :via => :post
  match 'taxa/flickr_photos_tagged'
  match 'taxa/tag_flickr_photos_from_observations', :via => :post
  match 'taxa/search' => 'taxa#search', :as => :search_taxa
  match 'taxa/search.:format' => 'taxa#search', :as => :formatted_search_taxa
  match 'taxa/:action.:format' => 'taxa#index', :as => :formatted_taxa_action
  match 'taxa/:id/merge' => 'taxa#merge', :as => :merge_taxon
  match 'taxa/:id/merge.:format' => 'taxa#merge', :as => :formatted_merge_taxon
  match 'taxa/:id/observation_photos' => 'taxa#observation_photos', :as => :taxon_observation_photos
  match 'taxa/observation_photos' => 'taxa#observation_photos'
  match 'taxa/:id/map' => 'taxa#map', :as => :taxon_map
  match 'taxa/map' => 'taxa#map', :as => :taxa_map
  match 'taxa/:id/range.:format' => 'taxa#range', :as => :taxon_range_geom
  match 'taxa/auto_complete_name' => 'taxa#auto_complete_name'
  match 'taxa/occur_in' => 'taxa#occur_in'
  match '/taxa/curation' => 'taxa#curation', :as => :curate_taxa
  match "taxa/*q" => 'taxa#try_show'
  
  resources :sources, :except => [:new, :create]
  match 'journal' => 'posts#browse', :as => :journals
  match 'journal/:login' => 'posts#index', :as => :journal_by_login, :constraints => { :login => simplified_login_regex }
  match 'journal/:login/archives/' => 'posts#archives', :as => :journal_archives, :constraints => { :login => simplified_login_regex }
  match 'journal/:login/archives/:year/:month' => 'posts#archives', :as => :journal_archives_by_month, :constraints => { :month => /\d{1,2}/, :year => /\d{1,4}/, :login => simplified_login_regex }
  match 'journal/:login/:id/edit' => 'posts#edit', :as => :edit_journal_post
  resources :posts, :except => [:index], :constraints => { :id => id_param_pattern } do
    resources :flags
  end
  resources :posts,
    :as => 'journal_posts',
    :path => "/journal/:login",
    :constraints => { :login => simplified_login_regex } do
    resources :flags
  end
  resources :trips, :constraints => { :id => id_param_pattern } do
    member do
      post :add_taxa_from_observations
      delete :remove_taxa
    end
  end
  match 'trips/:login' => 'trips#by_login', :as => :trips_by_login, :constraints => { :login => simplified_login_regex }
  
  resources :identifications, :constraints => { :id => id_param_pattern } do
    resources :flags
  end
  match 'identifications/bold' => 'identifications#bold', :via => :get
  match 'identifications/agree' => 'identifications#agree', :via => :post
  match 'identifications/:login' => 'identifications#by_login', :as => :identifications_by_login, :constraints => { :login => simplified_login_regex }, :via => :get
  match 'emailer/invite' => 'emailer#invite', :as => :emailer_invite
  match 'emailer/invite/send' => 'emailer#invite_send', :as => :emailer_invite_send, :via => :post
  resources :taxon_links, :except => [:show]
  
  match 'places/:id/widget' => 'places#widget', :as => :place_widget, :via => :get
  match 'places/guide_widget/:id' => 'places#guide_widget', :as => :place_guide_widget, :via => :get
  match '/places/find_external' => 'places#find_external', :as => :find_external
  match '/places/search' => 'places#search', :as => :place_search, :via => :get
  match '/places/:id/children' => 'places#children', :as => :place_children, :via => :get
  match 'places/:id/taxa.:format' => 'places#taxa', :as => :place_taxa, :via => :get
  match 'places/geometry/:id.:format' => 'places#geometry', :as => :place_geometry, :via => :get
  match 'places/guide/:id' => 'places#guide', :as => :place_guide, :via => :get
  match 'places/guide' => 'places#guide', :as => :idendotron_guide, :via => :get
  match 'places/cached_guide/:id' => 'places#cached_guide', :as => :cached_place_guide, :via => :get
  match 'places/autocomplete' => 'places#autocomplete', :as => :places_autocomplete
  resources :places
  
  # match '/guide' => 'places#guide', :as => :guide
  resources :flags
  match 'admin' => 'admin#index', :as => :admin
  match 'admin/user_content/:id/(:type)', :to => 'admin#user_content', :as => "admin_user_content"
  match 'admin/destroy_user_content/:id/:type', :to => 'admin#destroy_user_content', :as => "destroy_user_content", :via => :delete
  match 'admin/update_user/:id', :to => 'admin#update_user', :as => "admin_update_user", :via => :put
  resources :taxon_ranges, :except => [:index, :show]
  match '/calendar/:login' => 'calendars#index', :as => :calendar
  match '/calendar/:login/compare' => 'calendars#compare', :as => :calendar_compare
  match '/calendar/:login/:year/:month/:day' => 'calendars#show', :as => :calendar_date, :constraints => {
    :year => /\d+/,
    :month => /\d+/,
    :day => /\d+/
  }
  
  resources :subscriptions, :only => [:index, :new, :edit, :create, :update, :destroy]
  match 'subscriptions/:resource_type/:resource_id' => "subscriptions#destroy", :as => :delete_subscription, :via => :delete
  match 'subscriptions/:resource_type/:resource_id/edit' => "subscriptions#edit", :as => :edit_subscription_by_resource

  resources :taxon_changes, :constraints => { :id => id_param_pattern } do
    resources :taxon_change_taxa, :controller => :taxon_change_taxa, :shallow => true
    put :commit
    get :commit_for_user
    put 'commit_record/:type/:record_id/to/:taxon_id' => 'taxon_changes#commit_records', :as => :commit_record
    put 'commit_records/:type/(to/:taxon_id)' => 'taxon_changes#commit_records', :as => :commit_records
  end
  resources :taxon_schemes, :only => [:index, :show], :constraints => {:format => [:html, :mobile]}
  match 'taxon_schemes/:id/mapped_inactive_taxa' => 'taxon_schemes#mapped_inactive_taxa', :as => :mapped_inactive_taxa
  match 'taxon_schemes/:id/orphaned_inactive_taxa' => 'taxon_schemes#orphaned_inactive_taxa', :as => :orphaned_inactive_taxa
  
  resources :taxon_splits, :controller => :taxon_changes
  resources :taxon_merges, :controller => :taxon_changes
  resources :taxon_swaps, :controller => :taxon_changes
  resources :taxon_drops, :controller => :taxon_changes
  resources :taxon_stages, :controller => :taxon_changes
  resources :conservation_statuses, :only => [:autocomplete]
  
  if Rails.env.development?
    mount EmailerPreview => 'mail_view'
  end

  get 'translate' => 'translations#index', :as => :translate_list
  post 'translate/translate' => 'translations#translate', :as => :translate
  get 'translate/reload' => 'translations#reload', :as => :translate_reload
  
  match '/:controller(/:action(/:id))'
end
