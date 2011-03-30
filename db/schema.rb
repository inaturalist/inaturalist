# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110330050657) do

  create_table "activity_streams", :force => true do |t|
    t.column "user_id", :integer
    t.column "subscriber_id", :integer
    t.column "activity_object_id", :integer
    t.column "activity_object_type", :string
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "batch_ids", :string
  end

  add_index "activity_streams", ["subscriber_id"], :name => "index_activity_streams_on_subscriber_id"
  add_index "activity_streams", ["user_id", "activity_object_type"], :name => "index_activity_streams_on_user_id_and_activity_object_type"

  create_table "colors", :force => true do |t|
    t.column "value", :string
  end

  create_table "colors_taxa", :id => false, :force => true do |t|
    t.column "color_id", :integer
    t.column "taxon_id", :integer
  end

  add_index "colors_taxa", ["taxon_id", "color_id"], :name => "index_colors_taxa_on_taxon_id_and_color_id"

  create_table "comments", :force => true do |t|
    t.column "user_id", :integer
    t.column "parent_id", :integer
    t.column "parent_type", :string
    t.column "body", :text
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  add_index "comments", ["user_id"], :name => "index_comments_on_user_id"
  add_index "comments", ["parent_type", "parent_id"], :name => "index_comments_on_parent_type_and_parent_id"

  create_table "delayed_jobs", :force => true do |t|
    t.column "priority", :integer, :default => 0
    t.column "attempts", :integer, :default => 0
    t.column "handler", :text
    t.column "last_error", :text
    t.column "run_at", :datetime
    t.column "locked_at", :datetime
    t.column "failed_at", :datetime
    t.column "locked_by", :string
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  create_table "deleted_users", :force => true do |t|
    t.column "user_id", :integer
    t.column "login", :string
    t.column "email", :string
    t.column "user_created_at", :datetime
    t.column "user_updated_at", :datetime
    t.column "observations_count", :integer
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  add_index "deleted_users", ["user_id"], :name => "index_deleted_users_on_user_id"
  add_index "deleted_users", ["login"], :name => "index_deleted_users_on_login"

  create_table "flags", :force => true do |t|
    t.column "flag", :string, :default => ""
    t.column "comment", :string, :default => ""
    t.column "created_at", :datetime, :null => false
    t.column "flaggable_id", :integer, :default => 0, :null => false
    t.column "flaggable_type", :string, :limit => 15, :default => "", :null => false
    t.column "user_id", :integer, :default => 0, :null => false
    t.column "resolver_id", :integer
    t.column "resolved", :boolean, :default => false
  end

  add_index "flags", ["user_id"], :name => "fk_flags_user"

  create_table "flickr_identities", :force => true do |t|
    t.column "flickr_username", :string
    t.column "frob", :string
    t.column "token", :string
    t.column "token_created_at", :datetime
    t.column "auto_import", :integer, :default => 0
    t.column "auto_imported_at", :datetime
    t.column "user_id", :integer
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "flickr_user_id", :string
  end

  create_table "friendships", :force => true do |t|
    t.column "user_id", :integer
    t.column "friend_id", :integer
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  create_table "goal_contributions", :force => true do |t|
    t.column "contribution_id", :integer
    t.column "contribution_type", :string
    t.column "goal_id", :integer
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "goal_participant_id", :integer
  end

  create_table "goal_participants", :force => true do |t|
    t.column "goal_id", :integer
    t.column "user_id", :integer
    t.column "goal_completed", :integer, :default => 0
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  create_table "goal_rules", :force => true do |t|
    t.column "goal_id", :integer
    t.column "operator", :string
    t.column "operator_class", :string
    t.column "arguments", :string
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  create_table "goals", :force => true do |t|
    t.column "description", :text
    t.column "number_of_contributions_required", :integer
    t.column "goal_type", :string
    t.column "ends_at", :datetime
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "completed", :boolean, :default => false
  end

  create_table "identifications", :force => true do |t|
    t.column "observation_id", :integer
    t.column "taxon_id", :integer
    t.column "user_id", :integer
    t.column "type", :string
    t.column "body", :text
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  add_index "identifications", ["user_id", "created_at"], :name => "index_identifications_on_user_id_and_created_at"
  add_index "identifications", ["observation_id", "created_at"], :name => "index_identifications_on_observation_id_and_created_at"

  create_table "invites", :force => true do |t|
    t.column "user_id", :integer
    t.column "invite_address", :string
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  create_table "list_rules", :force => true do |t|
    t.column "list_id", :integer
    t.column "operator", :string
    t.column "operand_id", :integer
    t.column "operand_type", :string
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  add_index "list_rules", ["operand_type", "operand_id"], :name => "index_list_rules_on_operand_type_and_operand_id"
  add_index "list_rules", ["list_id"], :name => "index_list_rules_on_list_id"

  create_table "listed_taxa", :force => true do |t|
    t.column "taxon_id", :integer
    t.column "list_id", :integer
    t.column "last_observation_id", :integer
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "taxon_ancestor_ids", :string
    t.column "place_id", :integer
    t.column "description", :text
    t.column "comments_count", :integer, :default => 0
    t.column "user_id", :integer
    t.column "updater_id", :integer
    t.column "occurrence_status_level", :integer
    t.column "establishment_means", :string, :limit => 32
  end

  add_index "listed_taxa", ["list_id"], :name => "index_listed_taxa_on_list_id_and_lft"
  add_index "listed_taxa", ["list_id", "taxon_id"], :name => "index_listed_taxa_on_list_id_and_taxon_id"
  add_index "listed_taxa", ["taxon_id"], :name => "index_listed_taxa_on_taxon_id"
  add_index "listed_taxa", ["place_id", "taxon_id"], :name => "index_listed_taxa_on_place_id_and_taxon_id"
  add_index "listed_taxa", ["place_id", "created_at"], :name => "index_listed_taxa_on_place_id_and_created_at"
  add_index "listed_taxa", ["user_id"], :name => "index_listed_taxa_on_user_id"
  add_index "listed_taxa", ["list_id", "taxon_ancestor_ids", "taxon_id"], :name => "index_listed_taxa_on_list_id_and_taxon_ancestor_ids_and_taxon_id"

  create_table "lists", :force => true do |t|
    t.column "title", :string
    t.column "description", :text
    t.column "user_id", :integer
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "type", :string
    t.column "comprehensive", :boolean, :default => false
    t.column "taxon_id", :integer
    t.column "last_synced_at", :datetime
    t.column "place_id", :integer
    t.column "project_id", :integer
  end

  add_index "lists", ["user_id"], :name => "index_lists_on_user_id"
  add_index "lists", ["place_id"], :name => "index_lists_on_place_id"
  add_index "lists", ["project_id"], :name => "index_lists_on_project_id"

  create_table "observation_photos", :force => true do |t|
    t.column "observation_id", :integer, :null => false
    t.column "photo_id", :integer, :null => false
    t.column "position", :integer
  end

  add_index "observation_photos", ["observation_id"], :name => "index_observation_photos_on_observation_id"
  add_index "observation_photos", ["photo_id"], :name => "index_observation_photos_on_photo_id"

  create_table "observations", :force => true do |t|
    t.column "observed_on", :date
    t.column "description", :text
    t.column "latitude", :decimal, :precision => 15, :scale => 10
    t.column "longitude", :decimal, :precision => 15, :scale => 10
    t.column "map_scale", :integer
    t.column "timeframe", :text
    t.column "species_guess", :string
    t.column "user_id", :integer
    t.column "taxon_id", :integer
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "place_guess", :string
    t.column "id_please", :boolean, :default => false
    t.column "observed_on_string", :string
    t.column "iconic_taxon_id", :integer
    t.column "num_identification_agreements", :integer, :default => 0
    t.column "num_identification_disagreements", :integer, :default => 0
    t.column "time_observed_at", :datetime
    t.column "time_zone", :string
    t.column "location_is_exact", :boolean, :default => false
    t.column "delta", :boolean, :default => false
  end

  add_index "observations", ["user_id"], :name => "index_observations_on_user_id"
  add_index "observations", ["taxon_id", "user_id"], :name => "index_observations_on_taxon_id_and_user_id"
  add_index "observations", ["observed_on", "time_observed_at"], :name => "index_observations_on_observed_on_and_time_observed_at"
  add_index "observations", ["user_id", "observed_on", "time_observed_at"], :name => "index_observations_user_datetime"

  create_table "observations_posts", :id => false, :force => true do |t|
    t.column "observation_id", :integer, :null => false
    t.column "post_id", :integer, :null => false
  end

  add_index "observations_posts", ["observation_id"], :name => "index_observations_posts_on_observation_id"
  add_index "observations_posts", ["post_id"], :name => "index_observations_posts_on_post_id"

  create_table "passwords", :force => true do |t|
    t.column "user_id", :integer
    t.column "reset_code", :string
    t.column "expiration_date", :datetime
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  create_table "photos", :force => true do |t|
    t.column "user_id", :integer
    t.column "native_photo_id", :string
    t.column "square_url", :string
    t.column "thumb_url", :string
    t.column "small_url", :string
    t.column "medium_url", :string
    t.column "large_url", :string
    t.column "original_url", :string
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "native_page_url", :string
    t.column "native_username", :string
    t.column "native_realname", :string
    t.column "license", :integer
    t.column "type", :string
    t.column "file_content_type", :string
    t.column "file_file_name", :string
    t.column "file_file_size", :integer
    t.column "file_processing", :boolean
  end

  add_index "photos", ["native_photo_id"], :name => "index_flickr_photos_on_flickr_native_photo_id"

  create_table "picasa_identities", :force => true do |t|
    t.column "user_id", :integer
    t.column "token", :string
    t.column "token_created_at", :datetime
    t.column "picasa_user_id", :string
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  add_index "picasa_identities", ["user_id"], :name => "index_picasa_identities_on_user_id"

  create_table "place_geometries", :options=>'ENGINE=MyISAM', :force => true do |t|
    t.column "place_id", :integer
    t.column "source_name", :string
    t.column "source_identifier", :string
    t.column "geom", :multi_polygon, :null => false
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  add_index "place_geometries", ["place_id"], :name => "index_place_geometries_on_place_id"
  add_index "place_geometries", ["geom"], :name => "index_place_geometries_on_geom", :spatial=> true 

  create_table "places", :force => true do |t|
    t.column "name", :string
    t.column "display_name", :string
    t.column "code", :string
    t.column "latitude", :decimal, :precision => 15, :scale => 10
    t.column "longitude", :decimal, :precision => 15, :scale => 10
    t.column "swlat", :decimal, :precision => 15, :scale => 10
    t.column "swlng", :decimal, :precision => 15, :scale => 10
    t.column "nelat", :decimal, :precision => 15, :scale => 10
    t.column "nelng", :decimal, :precision => 15, :scale => 10
    t.column "woeid", :integer
    t.column "parent_id", :integer
    t.column "check_list_id", :integer
    t.column "place_type", :integer
    t.column "bbox_area", :float
    t.column "source_name", :string
    t.column "source_identifier", :string
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "delta", :boolean, :default => false
  end

  add_index "places", ["latitude", "longitude"], :name => "index_places_on_latitude_and_longitude"
  add_index "places", ["swlat", "swlng", "nelat", "nelng"], :name => "index_places_on_swlat_and_swlng_and_nelat_and_nelng"
  add_index "places", ["bbox_area"], :name => "index_places_on_bbox_area"
  add_index "places", ["parent_id"], :name => "index_places_on_parent_id"

  create_table "posts", :force => true do |t|
    t.column "parent_id", :integer, :null => false
    t.column "parent_type", :string, :null => false
    t.column "user_id", :integer, :null => false
    t.column "published_at", :datetime
    t.column "title", :string, :null => false
    t.column "body", :text
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  add_index "posts", ["published_at"], :name => "index_posts_on_published_at"

  create_table "project_observations", :force => true do |t|
    t.column "project_id", :integer
    t.column "observation_id", :integer
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  create_table "project_users", :force => true do |t|
    t.column "project_id", :integer
    t.column "user_id", :integer
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  create_table "projects", :force => true do |t|
    t.column "user_id", :integer
    t.column "title", :string
    t.column "description", :text
    t.column "terms", :text
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "icon_file_name", :string
    t.column "icon_content_type", :string
    t.column "icon_file_size", :integer
    t.column "icon_updated_at", :datetime
    t.column "auto_join", :boolean
  end

  create_table "roles", :force => true do |t|
    t.column "name", :string
  end

  create_table "roles_users", :id => false, :force => true do |t|
    t.column "role_id", :integer
    t.column "user_id", :integer
  end

  add_index "roles_users", ["role_id"], :name => "index_roles_users_on_role_id"
  add_index "roles_users", ["user_id"], :name => "index_roles_users_on_user_id"

  create_table "rules", :force => true do |t|
    t.column "type", :string
    t.column "ruler_type", :string
    t.column "ruler_id", :integer
    t.column "operand_type", :string
    t.column "operand_id", :integer
    t.column "operator", :string
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
  end

  create_table "sources", :force => true do |t|
    t.column "in_text", :string
    t.column "citation", :text
    t.column "url", :string
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "title", :string
  end

  create_table "taggings", :force => true do |t|
    t.column "tag_id", :integer
    t.column "taggable_id", :integer
    t.column "taggable_type", :string
    t.column "created_at", :datetime
  end

  add_index "taggings", ["tag_id"], :name => "index_taggings_on_tag_id"
  add_index "taggings", ["taggable_id", "taggable_type"], :name => "index_taggings_on_taggable_id_and_taggable_type"

  create_table "tags", :force => true do |t|
    t.column "name", :string
  end

  create_table "taxa", :force => true do |t|
    t.column "name", :string
    t.column "rank", :string
    t.column "source_identifier", :string
    t.column "source_url", :string
    t.column "parent_id", :integer
    t.column "source_id", :integer
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "iconic_taxon_id", :integer
    t.column "is_iconic", :boolean, :default => false
    t.column "auto_photos", :boolean, :default => true
    t.column "auto_description", :boolean, :default => true
    t.column "version", :integer
    t.column "lft", :integer
    t.column "rgt", :integer
    t.column "name_provider", :string
    t.column "delta", :boolean, :default => false
    t.column "creator_id", :integer
    t.column "updater_id", :integer
    t.column "observations_count", :integer, :default => 0
    t.column "listed_taxa_count", :integer, :default => 0
    t.column "rank_level", :integer
    t.column "unique_name", :string
    t.column "wikipedia_summary", :text
    t.column "wikipedia_title", :string
    t.column "featured_at", :datetime
    t.column "ancestry", :string
  end

  add_index "taxa", ["unique_name"], :name => "index_taxa_on_unique_name", :unique => true
  add_index "taxa", ["name"], :name => "index_taxa_on_name"
  add_index "taxa", ["parent_id"], :name => "index_taxa_on_parent_id"
  add_index "taxa", ["is_iconic"], :name => "index_taxa_on_is_iconic"
  add_index "taxa", ["lft"], :name => "index_taxa_on_lft"
  add_index "taxa", ["observations_count"], :name => "index_taxa_on_observations_count"
  add_index "taxa", ["listed_taxa_count"], :name => "index_taxa_on_listed_taxa_count"
  add_index "taxa", ["rank_level"], :name => "index_taxa_on_rank_level"
  add_index "taxa", ["featured_at"], :name => "index_taxa_on_featured_at"
  add_index "taxa", ["ancestry"], :name => "index_taxa_on_ancestry"

  create_table "taxon_links", :force => true do |t|
    t.column "url", :string, :null => false
    t.column "site_title", :string
    t.column "taxon_id", :integer, :null => false
    t.column "show_for_descendent_taxa", :boolean, :default => false
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "user_id", :integer
  end

  add_index "taxon_links", ["taxon_id", "show_for_descendent_taxa"], :name => "index_taxon_links_on_taxon_id_and_show_for_descendent_taxa"
  add_index "taxon_links", ["user_id"], :name => "index_taxon_links_on_user_id"

  create_table "taxon_names", :force => true do |t|
    t.column "name", :string
    t.column "is_valid", :boolean
    t.column "lexicon", :string
    t.column "source_identifier", :string
    t.column "source_url", :string
    t.column "taxon_id", :integer
    t.column "source_id", :integer
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "name_provider", :string
    t.column "creator_id", :integer
    t.column "updater_id", :integer
  end

  add_index "taxon_names", ["name"], :name => "index_taxon_names_on_name"
  add_index "taxon_names", ["taxon_id"], :name => "index_taxon_names_on_taxon_id"

  create_table "taxon_photos", :force => true do |t|
    t.column "taxon_id", :integer, :null => false
    t.column "photo_id", :integer, :null => false
    t.column "position", :integer
  end

  add_index "taxon_photos", ["taxon_id"], :name => "index_taxon_photos_on_taxon_id"
  add_index "taxon_photos", ["photo_id"], :name => "index_taxon_photos_on_photo_id"

  create_table "taxon_ranges", :force => true do |t|
    t.column "taxon_id", :integer
    t.column "source", :string
    t.column "start_month", :integer
    t.column "end_month", :integer
    t.column "geom", :multi_polygon
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "range_type", :string
    t.column "range_content_type", :string
    t.column "range_file_name", :string
    t.column "range_file_size", :integer
    t.column "description", :text
    t.column "source_id", :integer
  end

  create_table "taxon_versions", :force => true do |t|
    t.column "taxon_id", :integer
    t.column "version", :integer
    t.column "name", :string
    t.column "rank", :string
    t.column "source_identifier", :string
    t.column "source_url", :string
    t.column "parent_id", :integer
    t.column "source_id", :integer
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "iconic_taxon_id", :integer
    t.column "is_iconic", :boolean, :default => false
    t.column "auto_photos", :boolean, :default => true
    t.column "auto_description", :boolean, :default => true
    t.column "lft", :integer
    t.column "rgt", :integer
    t.column "name_provider", :string
    t.column "delta", :boolean, :default => false
    t.column "creator_id", :integer
    t.column "updater_id", :integer
    t.column "rank_level", :integer
  end

  create_table "users", :force => true do |t|
    t.column "login", :string, :limit => 40
    t.column "name", :string, :limit => 100, :default => ""
    t.column "email", :string, :limit => 100
    t.column "crypted_password", :string, :limit => 40
    t.column "salt", :string, :limit => 40
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "remember_token", :string, :limit => 40
    t.column "remember_token_expires_at", :datetime
    t.column "activation_code", :string, :limit => 40
    t.column "activated_at", :datetime
    t.column "state", :string, :default => "passive"
    t.column "deleted_at", :datetime
    t.column "time_zone", :string
    t.column "description", :string
    t.column "icon_file_name", :string
    t.column "icon_content_type", :string
    t.column "icon_file_size", :integer
    t.column "life_list_id", :integer
    t.column "observations_count", :integer, :default => 0
    t.column "identifications_count", :integer, :default => 0
    t.column "journal_posts_count", :integer, :default => 0
    t.column "life_list_taxa_count", :integer, :default => 0
    t.column "preferences", :text
  end

  add_index "users", ["login"], :name => "index_users_on_login", :unique => true
  add_index "users", ["observations_count"], :name => "index_users_on_observations_count"
  add_index "users", ["identifications_count"], :name => "index_users_on_identifications_count"
  add_index "users", ["journal_posts_count"], :name => "index_users_on_journal_posts_count"
  add_index "users", ["life_list_taxa_count"], :name => "index_users_on_life_list_taxa_count"
  add_index "users", ["state"], :name => "index_users_on_state"

end
