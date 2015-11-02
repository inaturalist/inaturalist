# Inaturalist::Application.routes.draw do
Rails.application.routes.draw do
  resources :guide_users


  apipie

  resources :sites


  id_param_pattern = %r(\d+([\w\-\%]*))
  simplified_login_regex = /\w[^\.,\/]+/  
  root :to => 'welcome#index'

  get "/set_locale", to: "application#set_locale", as: :set_locale

  resources :guide_sections do
    collection do
      get :import
    end
    resources :flags
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
      put :import_tags_from_csv
      get :import_tags_from_csv_template
      put :remove_all_tags
    end
    resources :flags
  end
  get '/guides/:id.:layout.pdf' => 'guides#show', :as => "guide_pdf", :constraints => {:format => :pdf}, :defaults => {:format => :pdf}
  get 'guides/user/:login' => 'guides#user', :as => :guides_by_login, :constraints => { :login => simplified_login_regex }
  
  resources :acts_as_votable_votes, controller: :votes, constraints: { id: id_param_pattern }, only: [:destroy]
  post 'votes/vote/:resource_type/:resource_id(.:format)' => 'votes#vote', as: :vote
  delete 'votes/unvote/:resource_type/:resource_id(.:format)' => 'votes#unvote', as: :unvote
  get  'votes/for/:resource_type/:resource_id(.:format)' => 'votes#for', as: :votes_for
  get  'faves/:login(.:format)' => 'votes#by_login', as: :faves_by_login, constraints: { login: simplified_login_regex }

  resources :messages, :except => [:edit, :update] do
    collection do
      get :count
      get :new_messages
    end
  end

  post '/oauth/assertion_token' => 'provider_oauth#assertion'
  get '/oauth/bounce' => 'provider_oauth#bounce', :as => "oauth_bounce"
  get '/oauth/bounce_back' => 'provider_oauth#bounce_back', :as => "oauth_bounce_back"
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
  get '/' => 'welcome#index'
  get '/home' => 'users#dashboard', :as => :home
  get '/home.:format' => 'users#dashboard', :as => :formatted_home
  
  get '/users/edit' => 'users#edit', :as => "generic_edit_user"
  devise_for :users, :controllers => {
    sessions: 'users/sessions',
    registrations: 'users/registrations',
    confirmations: 'users/confirmations'
  }
  devise_scope :user do
    get "login", :to => "users/sessions#new"
    get "logout", :to => "users/sessions#destroy"
    post "session", :to => "users/sessions#create"
    get "signup", :to => "users/registrations#new"
    get "users/new", :to => "users/registrations#new", :as => "new_user"
    get "/forgot_password", :to => "devise/passwords#new", :as => "forgot_password"
    put "users/update_session", :to => "users#update_session"
  end
  
  get '/activate/:activation_code' => 'users#activate', :as => :activate, :activation_code => nil
  get '/toggle_mobile' => 'welcome#toggle_mobile', :as => :toggle_mobile
  get '/help' => 'help#index', :as => :help
  get '/auth/failure' => 'provider_authorizations#failure', :as => :omniauth_failure
  get '/auth/:provider' => 'provider_authorizations#blank'
  get '/auth/:provider/callback' => 'provider_authorizations#create', :as => :omniauth_callback
  delete '/auth/:provider/disconnect' => 'provider_authorizations#destroy', :as => :omniauth_disconnect
  get '/users/edit_after_auth' => 'users#edit_after_auth', :as => :edit_after_auth
  get '/facebook/photo_fields' => 'facebook#photo_fields'
  get "/eol/photo_fields" => "eol#photo_fields"
  get '/wikimedia_commons/photo_fields' => 'wikimedia_commons#photo_fields'
  
  get '/flickr/invite' => 'photos#invite', :as => :flickr_accept_invite
  get '/facebook/invite' => 'photos#invite', :as => :fb_accept_invite
  get '/picasa/invite' => 'photos#invite', :as => :picasa_accept_invite

  match "/photos/inviter" => "photos#inviter", as: :photo_inviter, via: [:get, :post]
  post '/facebook' => 'facebook#index'
  
  resources :announcements
  get '/users/dashboard' => 'users#dashboard', :as => :dashboard
  get '/users/curation' => 'users#curation', :as => :curate_users
  get '/users/updates_count' => 'users#updates_count', :as => :updates_count
  get '/users/new_updates' => 'users#new_updates', :as => :new_updates
  
  resources :users, :except => [:new, :create] do
    resources :flags
  end
  # resource :session
  # resources :passwords
  resources :people, :controller => :users, :except => [:create] do
    collection do
      get :search
      get 'leaderboard(/:year(/:month))' => :leaderboard, :as => 'leaderboard_for'
    end
  end
  get '/users/:id/suspend' => 'users#suspend', :as => :suspend_user, :constraints => { :id => /\d+/ }
  get '/users/:id/unsuspend' => 'users#unsuspend', :as => :unsuspend_user, :constraints => { :id => /\d+/ }
  post 'users/:id/add_role' => 'users#add_role', :as => :add_role, :constraints => { :id => /\d+/ }
  post 'users/set_spammer' => 'users#set_spammer'
  post 'users/:id/set_spammer' => 'users#set_spammer', :as => :set_spammer, :constraints => { :id => /\d+/ }
  delete 'users/:id/remove_role' => 'users#remove_role', :as => :remove_role, :constraints => { :id => /\d+/ }
  get 'photos/local_photo_fields' => 'photos#local_photo_fields', :as => :local_photo_fields
  put '/photos/:id/repair' => "photos#repair", :as => :photo_repair
  resources :photos, :only => [:show, :update, :destroy] do
    resources :flags
    collection do
      get 'repair' => :fix
      post :repair_all
    end
    member do
      put :rotate
    end
  end
  delete 'picasa/unlink' => 'picasa#unlink'
  post 'flickr/unlink_flickr_account' => 'flickr#unlink_flickr_account'

  resources :observation_photos, :only => [:show, :create, :update, :destroy]
  get 'flickr/photos.:format' => 'flickr#photos'
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
      get :map
    end
    member do
      put :viewed_updates
      patch :update_fields
      post :review
    end
  end

  get 'observations/identotron' => 'observations#identotron', :as => :identotron
  post 'observations/update' => 'observations#update', :as => :update_observations
  get 'observations/new/batch_csv' => 'observations#new_batch_csv', :as => :new_observation_batch_csv
  match 'observations/new/batch' => 'observations#new_batch', :as => :new_observation_batch, :via => [ :get, :post ]
  post 'observations/new/bulk_csv' => 'observations#new_bulk_csv', :as => :new_observation_bulk_csv
  get 'observations/edit/batch' => 'observations#edit_batch', :as => :edit_observation_batch
  delete 'observations/delete_batch' => 'observations#delete_batch', :as => :delete_observation_batch
  get 'observations/import' => 'observations#import', :as => :import_observations
  match 'observations/import_photos' => 'observations#import_photos', :as => :import_photos, via: [ :get, :post ]
  post 'observations/import_sounds' => 'observations#import_sounds', :as => :import_sounds
  post 'observations/email_export/:id' => 'observations#email_export', :as => :email_export
  get 'observations/id_please' => 'observations#id_please', :as => :id_please
  get 'observations/selector' => 'observations#selector', :as => :observation_selector
  get '/observations/curation' => 'observations#curation', :as => :curate_observations
  get '/observations/widget' => 'observations#widget', :as => :observations_widget
  get 'observations/add_from_list' => 'observations#add_from_list', :as => :add_observations_from_list
  match 'observations/new_from_list' => 'observations#new_from_list', :as => :new_observations_from_list, via: [ :get, :post ]
  get 'observations/nearby' => 'observations#nearby', :as => :nearby_observations
  get 'observations/add_nearby' => 'observations#add_nearby', :as => :add_nearby_observations
  get 'observations/:id/edit_photos' => 'observations#edit_photos', :as => :edit_observation_photos
  post 'observations/:id/update_photos' => 'observations#update_photos', :as => :update_observation_photos
  get 'observations/:login' => 'observations#by_login', :as => :observations_by_login, :constraints => { :login => simplified_login_regex }
  get 'observations/:login.all' => 'observations#by_login_all', :as => :observations_by_login_all, :constraints => { :login => simplified_login_regex }
  get 'observations/:login.:format' => 'observations#by_login', :as => :observations_by_login_feed, :constraints => { :login => simplified_login_regex }
  get 'observations/project/:id' => 'observations#project', :as => :project_observations
  get 'observations/project/:id.all' => 'observations#project_all', :as => :all_project_observations
  get 'observations/of/:id.:format' => 'observations#of', :as => :observations_of
  match 'observations/:id/quality/:metric' => 'quality_metrics#vote', :as => :observation_quality, :via => [:post, :delete]
  

  match 'projects/:id/join' => 'projects#join', :as => :join_project, :via => [ :get, :post ]
  delete 'projects/:id/leave' => 'projects#leave', :as => :leave_project
  post 'projects/:id/add' => 'projects#add', :as => :add_project_observation
  match 'projects/:id/remove' => 'projects#remove', :as => :remove_project_observation, :via => [:post, :delete]
  post 'projects/:id/add_batch' => 'projects#add_batch', :as => :add_project_observation_batch
  match 'projects/:id/remove_batch' => 'projects#remove_batch', :as => :remove_project_observation_batch, :via => [:post, :delete]
  get 'projects/search' => 'projects#search', :as => :project_search
  get 'projects/search.:format' => 'projects#search', :as => :formatted_project_search
  get 'project/:id/terms' => 'projects#terms', :as => :project_terms
  get 'projects/user/:login' => 'projects#by_login', :as => :projects_by_login, :constraints => { :login => simplified_login_regex }
  get 'projects/:id/members' => 'projects#members', :as => :project_members
  get 'projects/:id/bulk_template' => 'projects#bulk_template', :as => :project_bulk_template
  get 'projects/:id/contributors' => 'projects#contributors', :as => :project_contributors
  get 'projects/:id/contributors.:format' => 'projects#contributors', :as => :formatted_project_contributors
  get 'projects/:id/observed_taxa_count' => 'projects#observed_taxa_count', :as => :project_observed_taxa_count
  get 'projects/:id/observed_taxa_count.:format' => 'projects#observed_taxa_count', :as => :formatted_project_observed_taxa_count
  get 'projects/:id/species_count.:format' => 'projects#observed_taxa_count', :as => :formatted_project_species_count
  get 'projects/:id/contributors/:project_user_id' => 'projects#show_contributor', :as => :project_show_contributor
  get 'projects/:id/make_curator/:project_user_id' => 'projects#make_curator', :as => :make_curator
  get 'projects/:id/remove_curator/:project_user_id' => 'projects#remove_curator', :as => :remove_curator
  get 'projects/:id/remove_project_user/:project_user_id' => 'projects#remove_project_user', :as => :remove_project_user
  post 'projects/:id/change_role/:project_user_id' => 'projects#change_role', :as => :change_project_user_role
  get 'projects/:id/stats' => 'projects#stats', :as => :project_stats
  get 'projects/:id/stats.:format' => 'projects#stats', :as => :formatted_project_stats
  get 'projects/browse' => 'projects#browse', :as => :browse_projects
  get 'projects/:id/invitations' => 'projects#invitations', :as => :invitations
  get 'projects/:project_id/journal/new' => 'posts#new', :as => :new_project_journal_post
  get 'projects/:project_id/journal' => 'posts#index', :as => :project_journal
  get 'projects/:project_id/journal/:id' => 'posts#show', :as => :project_journal_post
  delete 'projects/:project_id/journal/:id' => 'posts#destroy', :as => :delete_project_journal_post
  get 'projects/:project_id/journal/:id/edit' => 'posts#edit', :as => :edit_project_journal_post
  get 'projects/:project_id/journal/archives/:year/:month' => 'posts#archives', :as => :project_journal_archives_by_month, :constraints => { :month => /\d{1,2}/, :year => /\d{1,4}/ }

  resources :assessment_sections, :only => [:show] 
  resources :assessments, :only => [:new, :create, :show, :edit, :update, :destroy] do
    resources :assessment_sections, :only => [:new, :create, :show, :edit, :update] 
  end

  resources :projects do
    member do
      post :add_matching, :as => :add_matching_to
      get :preview_matching, :as => :preview_matching_for
      get :invite, :as => :invite_to
      get :confirm_leave
    end
    collection do
      get :calendar
    end
    resources :flags
    resources :assessments, :only => [:new, :create, :show, :index, :edit, :update]
  end

  resources :project_assets, :except => [:index, :show]
  resources :project_observations, :only => [:create, :destroy, :update]
  resources :custom_projects, :except => [:index, :show]
  resources :project_user_invitations, :only => [:create, :destroy]
  resources :project_users, only: [:update]

  get 'people/:login' => 'users#show', :as => :person_by_login, :constraints => { :login => simplified_login_regex }
  get 'people/:login/followers' => 'users#relationships', :as => :followers_by_login, :constraints => { :login => simplified_login_regex }, :followers => 'followers'
  get 'people/:login/following' => 'users#relationships', :as => :following_by_login, :constraints => { :login => simplified_login_regex }, :following => 'following'
  resources :lists, :constraints => { :id => id_param_pattern } do
    resources :flags
    get 'batch_edit'
  end
  get 'lists/:id/taxa' => 'lists#taxa', :as => :list_taxa
  get 'lists/:id/taxa.:format' => 'lists#taxa', :as => :formatted_list_taxa
  get 'lists/:id.:view_type.:format' => 'lists#show',
    :as => 'list_show_formatted_view',
    :requirements => { :id => id_param_pattern }
  resources :life_lists, :controller => :lists do
    resources :flags
  end
  resources :check_lists do
    resources :flags
  end
  resources :project_lists, :controller => :lists
  resources :listed_taxa do
    collection do
      post :refresh_observationcounts
    end
  end
  match 'lists/:login' => 'lists#by_login', :as => :lists_by_login, :constraints => { :login => simplified_login_regex }, :via => [ :get, :post ]
  get 'lists/:id/compare' => 'lists#compare', :as => :compare_lists, :constraints => { :id => /\d+([\w\-\%]*)/ }
  delete 'lists/:id/remove_taxon/:taxon_id' => 'lists#remove_taxon', :as => :list_remove_taxon, :constraints => { :id => /\d+([\w\-\%]*)/ }
  post 'lists/:id/add_taxon_batch' => 'lists#add_taxon_batch', :as => :list_add_taxon_batch, :constraints => { :id => /\d+([\w\-\%]*)/ }
  post 'check_lists/:id/add_taxon_batch' => 'check_lists#add_taxon_batch', :as => :check_list_add_taxon_batch, :constraints => { :id => /\d+([\w\-\%]*)/ }
  post 'lists/:id/reload_from_observations' => 'lists#reload_from_observations', :as => :list_reload_from_observations, :constraints => { :id => /\d+([\w\-\%]*)/ }
  post 'lists/:id/reload_and_refresh_now' => 'lists#reload_and_refresh_now', :as => :list_reload_and_refresh_now, :constraints => { :id => /\d+([\w\-\%]*)/ }
  post 'lists/:id/refresh_now_without_reload' => 'lists#refresh_now_without_reload', :as => :list_refresh_now_without_reload, :constraints => { :id => /\d+([\w\-\%]*)/ }
  post 'lists/:id/refresh' => 'lists#refresh', :as => :list_refresh, :constraints => { :id => /\d+([\w\-\%]*)/ }
  post 'lists/:id/add_from_observations_now' => 'lists#add_from_observations_now', :as => :list_add_from_observations_now, :constraints => { :id => /\d+([\w\-\%]*)/ }
  post 'lists/:id/refresh_now' => 'lists#refresh_now', :as => :list_refresh_now, :constraints => { :id => /\d+([\w\-\%]*)/ }
  post 'lists/:id/generate_csv' => 'lists#generate_csv', :as => :list_generate_csv, :constraints => { :id => /\d+([\w\-\%]*)/ }
  resources :comments do
    resources :flags
  end
  get 'comments/user/:login' => 'comments#user', :as => :comments_by_login, :constraints => { :login => simplified_login_regex }
  resources :project_invitations, :except => [:index, :show]
  post 'project_invitation/:id/accept' => 'project_invitations#accept', :as => :accept_project_invitation
  get 'taxa/names' => 'taxon_names#index'
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
      get 'synonyms'
    end
  end
  resources :taxon_names do
    member do
      delete :destroy_synonyms, :as => 'delete_synonyms_of'
    end
  end
  # get 'taxa/:id/description' => 'taxa#describe', :as => :describe_taxon
  patch 'taxa/:id/graft' => 'taxa#graft', :as => :graft_taxon
  get 'taxa/:id/children' => 'taxa#children', :as => :taxon_children
  get 'taxa/:id/children.:format' => 'taxa#children', :as => :formatted_taxon_children
  get 'taxa/:id/photos' => 'taxa#photos', :as => :taxon_photos
  get 'taxa/:id/edit_photos' => 'taxa#edit_photos', :as => :edit_taxon_photos
  put 'taxa/:id/update_colors' => 'taxa#update_colors', :as => :update_taxon_colors
  match 'taxa/:id/add_places' => 'taxa#add_places', :as => :add_taxon_places, :via => [ :get, :post ]
  get 'taxa/flickr_tagger' => 'taxa#flickr_tagger', :as => :flickr_tagger
  get 'taxa/flickr_tagger.:format' => 'taxa#flickr_tagger', :as => :formatted_flickr_tagger
  post 'taxa/tag_flickr_photos'
  get 'taxa/flickr_photos_tagged'
  post 'taxa/tag_flickr_photos_from_observations'
  get 'taxa/search' => 'taxa#search', :as => :search_taxa
  get 'taxa/search.:format' => 'taxa#search', :as => :formatted_search_taxa
  get 'taxa/:action.:format' => 'taxa#index', :as => :formatted_taxa_action
  match 'taxa/:id/merge' => 'taxa#merge', :as => :merge_taxon, :via => [ :get, :post ]
  get 'taxa/:id/merge.:format' => 'taxa#merge', :as => :formatted_merge_taxon
  get 'taxa/:id/observation_photos' => 'taxa#observation_photos', :as => :taxon_observation_photos
  get 'taxa/observation_photos' => 'taxa#observation_photos'
  get 'taxa/:id/map' => 'taxa#map', :as => :taxon_map
  get 'taxa/map' => 'taxa#map', :as => :taxa_map
  get 'taxa/:id/range.:format' => 'taxa#range', :as => :taxon_range_geom
  get 'taxa/auto_complete_name' => 'taxa#auto_complete_name'
  get 'taxa/occur_in' => 'taxa#occur_in'
  get '/taxa/curation' => 'taxa#curation', :as => :curate_taxa
  get "taxa/*q" => 'taxa#try_show'
  
  resources :sources, :except => [:new, :create]
  get 'journal' => 'posts#browse', :as => :journals
  get 'journal/:login' => 'posts#index', :as => :journal_by_login, :constraints => { :login => simplified_login_regex }
  get 'journal/:login/archives/' => 'posts#archives', :as => :journal_archives, :constraints => { :login => simplified_login_regex }
  get 'journal/:login/archives/:year/:month' => 'posts#archives', :as => :journal_archives_by_month, :constraints => { :month => /\d{1,2}/, :year => /\d{1,4}/, :login => simplified_login_regex }
  get 'journal/:login/:id/edit' => 'posts#edit', :as => :edit_journal_post
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
  get 'trips/:login' => 'trips#by_login', :as => :trips_by_login, :constraints => { :login => simplified_login_regex }
  
  resources :identifications, :constraints => { :id => id_param_pattern } do
    resources :flags
  end
  get 'identifications/bold' => 'identifications#bold'
  post 'identifications/agree' => 'identifications#agree'
  get 'identifications/:login' => 'identifications#by_login', :as => :identifications_by_login, :constraints => { :login => simplified_login_regex }
  get 'emailer/invite' => 'emailer#invite', :as => :emailer_invite
  post 'emailer/invite/send' => 'emailer#invite_send', :as => :emailer_invite_send
  resources :taxon_links, :except => [:show]
  
  get 'places/:id/widget' => 'places#widget', :as => :place_widget
  get 'places/guide_widget/:id' => 'places#guide_widget', :as => :place_guide_widget
  post '/places/find_external' => 'places#find_external', :as => :find_external
  get '/places/search' => 'places#search', :as => :place_search
  get '/places/:id/children' => 'places#children', :as => :place_children
  get 'places/:id/taxa.:format' => 'places#taxa', :as => :place_taxa
  get 'places/geometry/:id.:format' => 'places#geometry', :as => :place_geometry
  get 'places/guide/:id' => 'places#guide', :as => :place_guide
  get 'places/guide' => 'places#guide', :as => :idendotron_guide
  get 'places/cached_guide/:id' => 'places#cached_guide', :as => :cached_place_guide
  get 'places/autocomplete' => 'places#autocomplete', :as => :places_autocomplete
  resources :places do
    collection do
      get :planner
    end
    member do
      get :merge
      post :merge
    end
  end

  resources :flags
  resource :admin, only: :index, controller: :admin do
    collection do
      get :index
    end
  end

  resource :stats do
    collection do
      get :index
      get :summary
    end
  end

  get 'admin/user_content/:id/(:type)', :to => 'admin#user_content', :as => "admin_user_content"
  delete 'admin/destroy_user_content/:id/:type', :to => 'admin#destroy_user_content', :as => "destroy_user_content"
  put 'admin/update_user/:id', :to => 'admin#update_user', :as => "admin_update_user"
  resources :taxon_ranges, :except => [:show]
  get '/calendar/:login' => 'calendars#index', :as => :calendar
  get '/calendar/:login/compare' => 'calendars#compare', :as => :calendar_compare
  get '/calendar/:login/:year/:month/:day' => 'calendars#show', :as => :calendar_date, :constraints => {
    :year => /\d+/,
    :month => /\d+/,
    :day => /\d+/
  }
  
  resources :subscriptions, :only => [:index, :new, :edit, :create, :update, :destroy]
  delete 'subscriptions/:resource_type/:resource_id' => "subscriptions#destroy", :as => :delete_subscription
  get 'subscriptions/:resource_type/:resource_id/edit' => "subscriptions#edit", :as => :edit_subscription_by_resource
  post 'subscriptions/:resource_type/:resource_id/subscribe' => 'subscriptions#subscribe', as: :subscribe

  resources :taxon_changes, :constraints => { :id => id_param_pattern } do
    resources :taxon_change_taxa, :controller => :taxon_change_taxa, :shallow => true
    put :commit
    get :commit_for_user
    put 'commit_record/:type/:record_id/to/:taxon_id' => 'taxon_changes#commit_records', :as => :commit_record
    put 'commit_records/:type/(to/:taxon_id)' => 'taxon_changes#commit_records', :as => :commit_records
  end
  resources :taxon_schemes, :only => [:index, :show], :constraints => {:format => [:html, :mobile]}
  get 'taxon_schemes/:id/mapped_inactive_taxa' => 'taxon_schemes#mapped_inactive_taxa', :as => :mapped_inactive_taxa
  get 'taxon_schemes/:id/orphaned_inactive_taxa' => 'taxon_schemes#orphaned_inactive_taxa', :as => :orphaned_inactive_taxa
  
  resources :taxon_splits, :controller => :taxon_changes
  resources :taxon_merges, :controller => :taxon_changes
  resources :taxon_swaps, :controller => :taxon_changes
  resources :taxon_drops, :controller => :taxon_changes
  resources :taxon_stages, :controller => :taxon_changes
  resources :conservation_statuses, :only => [:autocomplete]

  get 'translate' => 'translations#index', :as => :translate_list
  post 'translate/translate' => 'translations#translate', :as => :translate
  get 'translate/reload' => 'translations#reload', :as => :translate_reload

  # Hack to enable mail previews. You could also remove get
  # '/:controller(/:action(/:id))' but that breaks a bunch of other stuff. You
  # could also fix that other stuff, if you're weren't a horrible person, but
  # you are.
  get '/rails/mailers/*path' => 'rails/mailers#preview'
  get '/:controller(/:action(/:id))'

  match '/404', to: 'errors#error_404', via: :all
  match '/422', to: 'errors#error_422', via: :all
  match '/500', to: 'errors#error_500', via: :all

end
