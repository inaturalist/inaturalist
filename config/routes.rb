# frozen_string_literal: true

Rails.application.routes.draw do
  resources :moderator_notes
  resources :data_partners
  resources :saved_locations
  # apipie

  resources :sites do
    collection do
      get :network
      get :affiliation
    end
    member do
      get :export
    end
  end

  uuid_pattern = BelongsToWithUuid::UUID_PATTERN.to_s.gsub( /[\^$]/, "" )
  id_param_pattern = /(\d+([\w\-%]*))|#{uuid_pattern}/
  simplified_login_regex = %r{\w[^.,/]+}
  root to: "welcome#index"

  # legacy routes
  get "/set_locale", to: "application#set_locale", as: :set_locale
  get "/ping", to: "application#ping"
  get "/seek", to: redirect( "/pages/seek_app", status: 302 )
  get "/terms", to: redirect( "/pages/terms" ), as: :terms_of_service
  get "/privacy", to: redirect( "/pages/privacy" ), as: :privacy_policy
  get "/users/new.mobile", to: redirect( "/signup" )
  get "/donate", to: "donate#index"
  get "/monthly-supporters", to: "donate#monthly_supporters", as: :monthly_supporters

  get "/donate-seek", to: redirect( "https://donorbox.org/support-seek-by-inaturalist", status: 302 )

  resources :controlled_terms
  resources :controlled_term_labels, only: [:create, :update, :destroy]
  resources :controlled_term_values, only: [:create, :destroy]
  resources :curator_applications, only: [:new, :create]
  resources :annotations

  get "/search" => "search#index", as: "search"

  resources :user_blocks, only: [:create, :destroy]
  resources :user_mutes, only: [:create, :destroy]
  resources :guide_users
  resources :taxon_curators, except: [:show, :index]

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
  get "guides/user/:login" => "guides#user", :as => :guides_by_login,
    :constraints => { login: simplified_login_regex }

  resources :acts_as_votable_votes, controller: :votes, constraints: { id: id_param_pattern }, only: [:destroy]
  post "votes/vote/:resource_type/:resource_id(.:format)" => "votes#vote", as: :vote
  delete "votes/unvote/:resource_type/:resource_id(.:format)" => "votes#unvote", as: :unvote
  get  "votes/for/:resource_type/:resource_id(.:format)" => "votes#for", as: :votes_for
  get  "faves/:login(.:format)" => "votes#by_login", as: :faves_by_login, constraints: { login: simplified_login_regex }

  resources :messages, except: [:edit, :update] do
    collection do
      get :count
      get :new_messages
    end
    resources :flags
  end

  post "/oauth/assertion_token" => "provider_oauth#assertion"

  use_doorkeeper do
    controllers applications: "oauth_applications",
      authorizations: "oauth_authorizations",
      authorized_applications: "oauth_authorized_applications",
      tokens: "oauth_tokens"
  end
  get "oauth/app_owner_application" => "oauth_applications#app_owner_application", :as => :app_owner_application
  post "oauth/create_app_owner_application" => "oauth_applications#create_app_owner_application",
    as: :create_app_owner_application

  wiki_root "/pages"
  get "/pages" => "wiki_pages#all", as: "wiki_all"

  # Riparian routes
  resources :flow_tasks do
    member do
      get :run
    end
  end

  resources :observation_field_values, only: [:create, :update, :destroy, :index]
  resources :observation_fields do
    member do
      get :merge
      put :merge, to: "observation_fields#merge_field"
    end
  end
  get "/" => "welcome#index"
  get "/home" => "users#dashboard", :as => :home
  get "/home.:format" => "users#dashboard", :as => :formatted_home
  get "/home" => "users#dashboard", as: :user_root

  get "/users/edit" => "users#edit", :as => "generic_edit_user"
  begin
    devise_for :users, controllers: {
      sessions: "users/sessions",
      registrations: "users/registrations",
      confirmations: "users/confirmations",
      passwords: "users/passwords"
    }
  rescue ActiveRecord::NoDatabaseError
    puts "Database not connected, failed to make routes for Devise. Ignore if setting up for the first time"
  end
  devise_scope :user do
    get "login", to: "users/sessions#new"
    get "logout", to: "users/sessions#destroy"
    post "session", to: "users/sessions#create"
    get "signup", to: "users/registrations#new"
    get "users/new", to: redirect( "signup" ), as: "new_user"
    # This *should* be a redirect, but that is messing with the way we're doing
    # get "/forgot_password", to: redirect( "/users/password/new" ), as: "forgot_password"
    get "/forgot_password", to: "users/passwords#new", as: "forgot_password"
    put "users/update_session", to: "users#update_session"
  end

  get "/activate/:activation_code" => "users#activate", :as => :activate, :activation_code => nil
  get "/auth/failure" => "provider_authorizations#failure", :as => :omniauth_failure
  post "/auth/:provider" => "provider_authorizations#blank"
  get "/auth/:provider/callback" => "provider_authorizations#create", :as => :omniauth_callback
  post "/auth/:provider/callback" => "provider_authorizations#create", :as => :omniauth_callback_post
  delete "/auth/:provider/disconnect" => "provider_authorizations#destroy", :as => :omniauth_disconnect
  delete "/provider_authorizations/:id" => "provider_authorizations#destroy"
  get "/users/edit_after_auth" => "users#edit_after_auth", :as => :edit_after_auth
  get "/facebook/photo_fields" => "facebook#photo_fields"
  get "/eol/photo_fields" => "eol#photo_fields"
  get "/wikimedia_commons/photo_fields" => "wikimedia_commons#photo_fields"
  post "/facebook" => "facebook#index"

  resource :help, controller: :help, only: :index do
    collection do
      get :index
      get :getting_started
    end
  end

  resources :announcements do
    member do
      put :dismiss
    end
  end
  get "/users/dashboard" => "users#dashboard", :as => :dashboard
  get "/users/curation" => "users#curation", :as => :curate_users
  get "/users/updates_count" => "users#updates_count", :as => :updates_count
  get "/users/new_updates" => "users#new_updates", :as => :new_updates
  get "/users/api_token" => "users#api_token", :as => :api_token
  get "/users/dashboard_updates" => "users#dashboard_updates", :as => :dashboard_updates

  resources :users, except: [:new, :create] do
    resources :flags
    collection do
      get :recent
      get :delete
      post :parental_consent
      post :resend_confirmation
    end
    member do
      put :join_test
      put :leave_test
      put :merge
      put :trust
      put :untrust
    end
  end
  # resource :session
  # resources :passwords
  resources :people, controller: :users, except: [:create] do
    collection do
      get "leaderboard(/:year(/:month))" => :leaderboard, :as => "leaderboard_for"
    end
    member do
      get :moderation
    end
  end
  resources :relationships, controller: :relationships, only: [:index, :create, :update, :destroy]
  get "/users/:id/suspend" => "users#suspend", :as => :suspend_user, :constraints => { id: /\d+/ }
  get "/users/:id/unsuspend" => "users#unsuspend", :as => :unsuspend_user, :constraints => { id: /\d+/ }
  post "users/:id/add_role" => "users#add_role", :as => :add_role, :constraints => { id: /\d+/ }
  post "users/set_spammer" => "users#set_spammer"
  post "users/:id/set_spammer" => "users#set_spammer", :as => :set_spammer, :constraints => { id: /\d+/ }
  delete "users/:id/remove_role" => "users#remove_role", :as => :remove_role, :constraints => { id: /\d+/ }
  post "users/:id/mute" => "users#mute", as: :mute_user
  delete "users/:id/mute" => "users#unmute", as: :unmute_user
  post "users/:id/block" => "users#block", as: :block_user
  delete "users/:id/block" => "users#unblock", as: :unblock_user
  get "photos/local_photo_fields" => "photos#local_photo_fields", :as => :local_photo_fields
  put "/photos/:id/repair" => "photos#repair", :as => :photo_repair
  resources :photos, only: [:show, :update, :destroy, :create] do
    resources :flags
    collection do
      get "repair" => :fix
      post :repair_all
    end
    member do
      put :rotate
    end
  end

  post "flickr/unlink_flickr_account" => "flickr#unlink_flickr_account"
  get "flickr/photos.:format" => "flickr#photos"
  get "flickr/options" => "flickr#options", as: "flickr_options"
  get "flickr/photo_fields" => "flickr#photo_fields", as: "flickr_photo_fields"
  delete "flickr/remove_tag" => "flickr/remove_tag", as: "flickr_remove_tag"

  resources :observation_photos, only: [:show, :create, :update, :destroy]
  resources :observation_sounds, only: [:show, :create, :update, :destroy]
  resources :soundcloud_sounds, only: [:index]
  resources :sounds, only: [:show, :local_sound_fields, :create] do
    resources :flags
    collection do
      get :local_sound_fields
    end
  end
  resources :observations, constraints: { id: id_param_pattern } do
    resources :flags
    get "fields", as: "extra_fields"
    get "community_taxon_summary"
    collection do
      get :upload
      get :stats
      get :taxa
      get :taxon_stats
      get :user_stats
      get :export
      get :map
      get :identify
      get :torquemap
      get :compare
    end
    member do
      get :taxon_summary
      get :observation_links
      put :viewed_updates
      patch :update_fields
      post :review
      delete :review, as: "unreview"
    end
  end

  get "observations/identotron" => "observations#identotron", :as => :identotron
  post "observations/update" => "observations#update", :as => :update_observations
  get "observations/new/batch_csv" => "observations#new_batch_csv", :as => :new_observation_batch_csv
  match "observations/new/batch" => "observations#new_batch", :as => :new_observation_batch, :via => [:get, :post]
  post "observations/new/bulk_csv" => "observations#new_bulk_csv", :as => :new_observation_bulk_csv
  get "observations/edit/batch" => "observations#edit_batch", :as => :edit_observation_batch
  delete "observations/delete_batch" => "observations#delete_batch", :as => :delete_observation_batch
  get "observations/import" => "observations#import", :as => :import_observations
  match "observations/import_photos" => "observations#import_photos", :as => :import_photos, via: [:get, :post]
  post "observations/import_sounds" => "observations#import_sounds", :as => :import_sounds
  post "observations/email_export/:id" => "observations#email_export", :as => :email_export
  get "observations/id_please" => "observations#id_please", :as => :id_please
  get "observations/selector" => "observations#selector", :as => :observation_selector
  get "/observations/curation" => "observations#curation", :as => :curate_observations
  get "/observations/widget" => "observations#widget", :as => :observations_widget
  get "observations/add_from_list" => "observations#add_from_list", :as => :add_observations_from_list
  match "observations/new_from_list" => "observations#new_from_list", :as => :new_observations_from_list,
    via: [:get, :post]
  get "observations/nearby" => "observations#nearby", :as => :nearby_observations
  get "observations/add_nearby" => "observations#add_nearby", :as => :add_nearby_observations
  get "observations/:id/edit_photos" => "observations#edit_photos", :as => :edit_observation_photos
  post "observations/:id/update_photos" => "observations#update_photos", :as => :update_observation_photos
  get "observations/:login" => "observations#by_login", :as => :observations_by_login,
    :constraints => { login: simplified_login_regex }
  get "observations/:login.all" => "observations#by_login_all", :as => :observations_by_login_all,
    :constraints => { login: simplified_login_regex }
  get "observations/:login.:format" => "observations#by_login", :as => :observations_by_login_feed,
    :constraints => { login: simplified_login_regex }
  get "observations/project/:id.:format" => "observations#project", as: :observations_for_project
  get "observations/project/:id.all" => "observations#project_all", :as => :all_project_observations
  match "observations/:id/quality/:metric" => "quality_metrics#vote", :as => :observation_quality,
    :via => [:post, :delete]

  match "projects/:id/join" => "projects#join", :as => :join_project, :via => [:get, :post]
  delete "projects/:id/leave" => "projects#leave", :as => :leave_project
  post "projects/:id/add" => "projects#add", :as => :add_project_observation
  match "projects/:id/remove" => "projects#remove", :as => :remove_project_observation, :via => [:post, :delete]
  post "projects/:id/add_batch" => "projects#add_batch", :as => :add_project_observation_batch
  match "projects/:id/remove_batch" => "projects#remove_batch", :as => :remove_project_observation_batch,
    :via => [:post, :delete]
  get "projects/search" => "projects#search", :as => :project_search
  get "projects/search.:format" => "projects#search", :as => :formatted_project_search
  get "project/:id/terms" => "projects#terms", :as => :project_terms
  get "projects/user/:login" => "projects#by_login", :as => :projects_by_login,
    :constraints => { login: simplified_login_regex }
  get "projects/:id/members" => "projects#members", :as => :project_members
  get "projects/:id/bulk_template" => "projects#bulk_template", :as => :project_bulk_template
  get "projects/:id/contributors" => "projects#contributors", :as => :project_contributors
  get "projects/:id/contributors.:format" => "projects#contributors", :as => :formatted_project_contributors
  get "projects/:id/observed_taxa_count" => "projects#observed_taxa_count", :as => :project_observed_taxa_count
  get "projects/:id/observed_taxa_count.:format" => "projects#observed_taxa_count",
    :as => :formatted_project_observed_taxa_count
  get "projects/:id/species_count.:format" => "projects#observed_taxa_count", :as => :formatted_project_species_count
  get "projects/:id/contributors/:project_user_id" => "projects#show_contributor", :as => :project_show_contributor
  get "projects/:id/make_curator/:project_user_id" => "projects#make_curator", :as => :make_curator
  get "projects/:id/remove_curator/:project_user_id" => "projects#remove_curator", :as => :remove_curator
  get "projects/:id/remove_project_user/:project_user_id" => "projects#remove_project_user", :as => :remove_project_user
  post "projects/:id/change_role/:project_user_id" => "projects#change_role", :as => :change_project_user_role
  get "projects/:id/stats" => "projects#stats", :as => :project_stats
  get "projects/:id/stats.:format" => "projects#stats", :as => :formatted_project_stats
  get "projects/browse" => "projects#browse", :as => :browse_projects
  get "projects/:id/invitations" => "projects#invitations", :as => :invitations
  get "projects/:project_id/journal/new" => "posts#new", :as => :new_project_journal_post
  get "projects/:project_id/journal" => "posts#index", :as => :project_journal
  get "projects/:project_id/journal/:id" => "posts#show", :as => :project_journal_post
  delete "projects/:project_id/journal/:id" => "posts#destroy", :as => :delete_project_journal_post
  get "projects/:project_id/journal/:id/edit" => "posts#edit", :as => :edit_project_journal_post
  get "projects/:project_id/journal/archives/:year/:month" => "posts#archives",
    :as => :project_journal_archives_by_month, :constraints => { month: /\d{1,2}/, year: /\d{1,4}/ }

  resources :assessment_sections, only: [:show]
  resources :assessments, only: [:new, :create, :show, :edit, :update, :destroy] do
    resources :assessment_sections, only: [:new, :create, :show, :edit, :update]
  end

  resources :projects do
    member do
      get :invite, as: :invite_to
      get :confirm_leave
      get :stats_slideshow
      put "change_admin/:user_id" => "projects#change_admin", as: :change_admin
      get :convert_to_collection
      get :convert_to_traditional
      put :feature
      put :unfeature
    end
    collection do
      get :calendar
      get :new_traditional
    end
    resources :flags
    resources :assessments, only: [:new, :create, :show, :index, :edit, :update]
  end

  resources :project_assets, except: [:index, :show]
  resources :project_observations, only: [:create, :destroy, :update]
  resources :custom_projects, except: [:index, :show]
  resources :project_user_invitations, only: [:create, :destroy]
  resources :project_users, only: [:update]

  get "people/:login" => "users#show", :as => :person_by_login, :constraints => { login: simplified_login_regex }
  get "people/:login/followers" => "users#followers", as: :followers_by_login,
    constraints: { login: simplified_login_regex }
  get "people/:login/following" => "users#following", as: :following_by_login,
    constraints: { login: simplified_login_regex }
  resources :lists, constraints: { id: id_param_pattern } do
    resources :flags
    get "batch_edit"
    member do
      get :icon_preview
    end
  end
  get "lists/:id/taxa" => "lists#taxa", :as => :list_taxa
  get "lists/:id/taxa.:format" => "lists#taxa", :as => :formatted_list_taxa
  get "lists/:id.:view_type.:format" => "lists#show",
    :as => "list_show_formatted_view",
    :requirements => { id: id_param_pattern }
  resources :check_lists do
    resources :flags
  end
  resources :project_lists, controller: :lists
  resources :listed_taxa do
    collection do
      post :refresh_observationcounts
    end
  end
  match "lists/:login" => "lists#by_login", :as => :lists_by_login,
    :constraints => { login: simplified_login_regex }, :via => [:get, :post]
  get "lists/:id/compare" => "lists#compare", :as => :compare_lists, :constraints => { id: /\d+([\w\-%]*)/ }
  delete "lists/:id/remove_taxon/:taxon_id" => "lists#remove_taxon", :as => :list_remove_taxon,
    :constraints => { id: /\d+([\w\-%]*)/ }
  post "lists/:id/add_taxon_batch" => "lists#add_taxon_batch", :as => :list_add_taxon_batch,
    :constraints => { id: /\d+([\w\-%]*)/ }
  post "lists/:id/generate_csv" => "lists#generate_csv", :as => :list_generate_csv,
    :constraints => { id: /\d+([\w\-%]*)/ }
  post "lists/:id/refresh_now" => "lists#refresh_now", :as => :list_refresh_now,
    :constraints => { id: /\d+([\w\-%]*)/ }
  post "lists/:id/add_from_observations_now" => "lists#add_from_observations_now",
    :as => :list_add_from_observations_now, :constraints => { id: /\d+([\w\-%]*)/ }
  post "check_lists/:id/add_taxon_batch" => "check_lists#add_taxon_batch", :as => :check_list_add_taxon_batch,
    :constraints => { id: /\d+([\w\-%]*)/ }
  resources :comments, constraints: { id: id_param_pattern } do
    resources :flags
  end
  get "comments/user/:login" => "comments#user", :as => :comments_by_login,
    :constraints => { login: simplified_login_regex }
  resources :taxon_photos, constraints: { id: id_param_pattern }, only: [:new, :create]
  get "taxa/names" => "taxon_names#index"
  resources :taxa, constraints: { id: id_param_pattern } do
    resources :flags
    resources :taxon_names, controller: :taxon_names, shallow: true
    resources :taxon_scheme_taxa, controller: :taxon_scheme_taxa, shallow: true
    resources :conservation_statuses, controller: :conservation_statuses, shallow: true
    get "description" => "taxa#describe", on: :member, as: :describe
    member do
      post "update_photos", as: "update_photos_for"
      post "set_photos", as: "set_photos_for"
      post "refresh_wikipedia_summary", as: "refresh_wikipedia_summary_for"
      get "schemes", as: "schemes_for", constraints: { format: [:html] }
      get "tip"
      get "names", to: "taxon_names#taxon"
      get "links"
      get "map_layers"
      get "browse_photos"
      get "taxonomy_details", as: "taxonomy_details_for"
      get "show_google"
      get "taxobox"
      get "history"
    end
    collection do
      get "synonyms"
      get :autocomplete
    end
  end
  resources :taxon_names do
    member do
      delete :destroy_synonyms, as: "delete_synonyms_of"
    end
  end
  # get 'taxa/:id/description' => 'taxa#describe', :as => :describe_taxon
  patch "taxa/:id/graft" => "taxa#graft", :as => :graft_taxon
  get "taxa/:id/children" => "taxa#children", :as => :taxon_children
  get "taxa/:id/children.:format" => "taxa#children", :as => :formatted_taxon_children
  get "taxa/:id/photos" => "taxa#photos", as: :photos_of_taxon
  put "taxa/:id/update_colors" => "taxa#update_colors", :as => :update_taxon_colors
  get "taxa/:id/clashes" => "taxa#clashes", :as => :taxa_clashes
  get "taxa/flickr_tagger" => "taxa#flickr_tagger", :as => :flickr_tagger
  get "taxa/flickr_tagger.:format" => "taxa#flickr_tagger", :as => :formatted_flickr_tagger
  post "taxa/tag_flickr_photos"
  get "taxa/flickr_photos_tagged"
  post "taxa/tag_flickr_photos_from_observations"
  get "taxa/search" => "taxa#search", :as => :search_taxa
  get "taxa/search.:format" => "taxa#search", :as => :formatted_search_taxa
  match "taxa/:id/merge" => "taxa#merge", :as => :merge_taxon, :via => [:get, :post]
  get "taxa/:id/merge.:format" => "taxa#merge", :as => :formatted_merge_taxon
  get "taxa/:id/observation_photos" => "taxa#observation_photos", :as => :taxon_observation_photos
  get "taxa/observation_photos" => "taxa#observation_photos"
  get "taxa/:id/map" => "taxa#map", :as => :taxon_map
  get "taxa/map" => "taxa#map", :as => :taxa_map
  get "taxa/:id/range.:format" => "taxa#range", :as => :taxon_range_geom
  get "taxa/auto_complete_name" => "taxa#auto_complete_name"
  get "taxa/occur_in" => "taxa#occur_in"
  get "/taxa/curation" => "taxa#curation", :as => :curate_taxa
  get "taxa/*q" => "taxa#try_show", as: :taxa_try_show

  resources :sources
  get "journal" => "posts#browse", :as => :journals
  get "journal/:login" => "posts#index", :as => :journal_by_login, :constraints => { login: simplified_login_regex }
  get "journal/:login/archives/" => "posts#archives", :as => :journal_archives,
    :constraints => { login: simplified_login_regex }
  get "journal/:login/archives/:year/:month" => "posts#archives", :as => :journal_archives_by_month,
    :constraints => { month: /\d{1,2}/, year: /\d{1,4}/, login: simplified_login_regex }
  get "journal/:login/:id/edit" => "posts#edit", :as => :edit_journal_post
  resources :posts, constraints: { id: id_param_pattern } do
    resources :flags
    collection do
      get :for_project_user
      get :for_user
    end
  end
  get "/posts/search", to: "posts#search"
  resources :posts,
    as: "journal_posts",
    path: "/journal/:login",
    constraints: { login: simplified_login_regex } do
    resources :flags
  end
  resources :posts, as: "site_posts", path: "/blog" do
    resources :flags
    collection do
      get "archives/:year/:month" => "posts#archives", as: :archives_by_month, constraints: {
        month: /\d{1,2}/,
        year: /\d{1,4}/
      }
      get :archives
    end
  end
  resources :trips, constraints: { id: id_param_pattern } do
    member do
      post :add_taxa_from_observations
      delete :remove_taxa
    end
    collection do
      get :tabulate
    end
  end
  get "trips/:login" => "trips#by_login", :as => :trips_by_login, :constraints => { login: simplified_login_regex }

  resources :identifications, constraints: { id: id_param_pattern } do
    resources :flags
  end
  get "identifications/bold" => "identifications#bold"
  post "identifications/agree" => "identifications#agree"
  get "identifications/:login" => "identifications#by_login", :as => :identifications_by_login,
    :constraints => { login: simplified_login_regex }
  resources :taxon_links

  get "places/:id/widget" => "places#widget", :as => :place_widget
  get "places/guide_widget/:id" => "places#guide_widget", :as => :place_guide_widget
  post "/places/find_external" => "places#find_external", :as => :find_external
  get "/places/search" => "places#search", :as => :place_search
  get "/places/:id/children" => "places#children", :as => :place_children
  get "places/:id/taxa.:format" => "places#taxa", :as => :place_taxa
  get "places/geometry/:id.:format" => "places#geometry", :as => :place_geometry
  get "places/guide/:id" => "places#guide", :as => :place_guide
  get "places/guide" => "places#guide", :as => :idendotron_guide
  get "places/cached_guide/:id" => "places#cached_guide", :as => :cached_place_guide
  get "places/autocomplete" => "places#autocomplete", :as => :places_autocomplete
  get "places/wikipedia/:id" => "places#wikipedia", :as => :places_wikipedia
  resources :places do
    resources :flags
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
      get :queries
      get :users
      get "users/:id" => "admin#user_detail", as: :user_detail
      get "login_as/:id" => "admin#login_as", as: :login_as
      get :deleted_users
      put :grant_user_privilege
      put :revoke_user_privilege
      put :restore_user_privilege
      put :reset_user_privilege
    end
    resources :delayed_jobs, only: :index, controller: "admin/delayed_jobs" do
      member do
        get :unlock
      end
      collection do
        get :index
        get :active
        get :failed
        get :pending
      end
    end
  end
  get "admin/user_content/:id/(:type)", to: "admin#user_content", as: "admin_user_content"
  delete "admin/destroy_user_content/:id/:type", to: "admin#destroy_user_content", as: "destroy_user_content"
  put "admin/update_user/:id", to: "admin#update_user", as: "admin_update_user"

  resources :site_admins, only: [:create, :destroy] do
    collection do
      delete :destroy
    end
  end

  resource :stats do
    collection do
      get :index
      get :summary
      get :nps_bioblitz
      get :cnc2016
      get :cnc2017
      get :cnc2017_stats
      get :canada_150
      get :parks_canada_2017
      get ":year", as: "year", to: "stats#year", constraints: { year: /\d+/ }
      get ":year/you", as: "your_year", to: "stats#your_year", constraints: { year: /\d+/ }
      get ":year/:login", as: "user_year", to: "stats#year", constraints: { year: /\d+/ }
      post :generate_year
    end
  end

  resources :taxon_ranges

  resources :atlases do
    member do
      post :alter_atlas_presence
      post :destroy_all_alterations
      post :remove_atlas_alteration
      post :remove_listed_taxon_alteration
      post :refresh_atlas
      get :get_defaults_for_taxon_place
    end
  end
  resources :exploded_atlas_places

  resources :complete_sets do
    member do
      post :destroy_relevant_listings
      post :remove_listed_taxon_alteration
      get :get_relevant_listings
    end
  end

  get "/calendar/:login" => "calendars#index", :as => :calendar
  get "/calendar/:login/compare" => "calendars#compare", :as => :calendar_compare
  get "/calendar/:login/:year/:month/:day" => "calendars#show", :as => :calendar_date, :constraints => {
    year: /\d+/,
    month: /\d+/,
    day: /\d+/
  }

  resources :subscriptions, only: [:index, :new, :edit, :create, :update, :destroy]
  delete "subscriptions/:resource_type/:resource_id" => "subscriptions#destroy", :as => :delete_subscription
  get "subscriptions/:resource_type/:resource_id/edit" => "subscriptions#edit", :as => :edit_subscription_by_resource
  post "subscriptions/:resource_type/:resource_id/subscribe" => "subscriptions#subscribe", as: :subscribe

  resources :taxon_changes, constraints: { id: id_param_pattern } do
    resources :taxon_change_taxa, controller: :taxon_change_taxa, shallow: true
    collection do
      get "group/:group" => "taxon_changes#group", as: :group
    end
    put :commit
    get :commit_for_user
    put "commit_record/:type/:record_id/to/:taxon_id" => "taxon_changes#commit_records", as: :commit_record
    put "commit_records/:type/(to/:taxon_id)" => "taxon_changes#commit_records", as: :commit_records
    post :analyze_ids
  end
  post "/taxon_changes/analyze_ids" => "taxon_changes#analyze_ids", as: :analyze_ids
  resources :taxon_schemes, only: [:index, :show], constraints: { format: [:html] }
  get "taxon_schemes/:id/mapped_inactive_taxa" => "taxon_schemes#mapped_inactive_taxa", :as => :mapped_inactive_taxa
  get "taxon_schemes/:id/orphaned_inactive_taxa" => "taxon_schemes#orphaned_inactive_taxa",
    :as => :orphaned_inactive_taxa

  resources :taxon_framework_relationships
  get "taxon_frameworks/:id/relationship_unknown" => "taxon_frameworks#relationship_unknown",
    :as => :relationship_unknown

  resources :taxon_frameworks, except: [:show, :index]

  resources :taxon_splits, controller: :taxon_changes
  resources :taxon_merges, controller: :taxon_changes
  resources :taxon_swaps, controller: :taxon_changes
  resources :taxon_drops, controller: :taxon_changes
  resources :taxon_stages, controller: :taxon_changes

  resources :conservation_statuses, only: [:create, :destroy]

  resource :computer_vision_demo, only: :index, controller: :computer_vision_demo do
    collection do
      get :index
    end
  end

  resources :computer_vision_demo_uploads do
    member do
      post :score
    end
  end
  resources :user_parents, only: [:index, :new, :create, :destroy] do
    member do
      get :confirm
    end
  end
  resources :moderator_actions, only: [:create]

  resource :lifelists, only: [] do
    collection do
      get ":login", to: "lifelists#by_login", as: "by_login"
    end
  end

  resources :picasa do
    collection do
      get :options
      get :photo_fields
      delete :unlink
    end
  end

  get "translate" => "translations#index", :as => :translate_list
  post "translate/translate" => "translations#translate", :as => :translate
  get "translate/reload" => "translations#reload", :as => :translate_reload

  resource :translations do
    collection do
      get :index
      get :locales
    end
  end

  resources :email_suppressions, only: [:index, :destroy]

  get "apple-app-site-association" => "apple_app_site_association#index", as: :apple_app_site_association

  # Hack to enable mail previews. You could also remove get
  # '/:controller(/:action(/:id))' but that breaks a bunch of other stuff. You
  # could also fix that other stuff, if you're weren't a horrible person, but
  # you are.
  unless Rails.env.production?
    get "/rails/mailers/*path" => "rails/mailers#preview"
  end
  # get "/:controller(/:action(/:id))", defaults: { from_dynamic_route: true}

  match "/404", to: "errors#error_404", via: :all
  match "/422", to: "errors#error_422", via: :all
  match "/500", to: "errors#error_500", via: :all
end
