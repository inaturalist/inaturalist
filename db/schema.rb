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

ActiveRecord::Schema.define(:version => 20120425042326) do

  create_table "activity_streams", :force => true do |t|
    t.integer  "user_id"
    t.integer  "subscriber_id"
    t.integer  "activity_object_id"
    t.string   "activity_object_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "batch_ids",            :limit => 512
  end

  add_index "activity_streams", ["subscriber_id"], :name => "index_activity_streams_on_subscriber_id"
  add_index "activity_streams", ["user_id", "activity_object_type"], :name => "index_activity_streams_on_user_id_and_activity_object_type"

  create_table "announcements", :force => true do |t|
    t.string   "placement"
    t.datetime "start"
    t.datetime "end"
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "colors", :force => true do |t|
    t.string "value"
  end

  create_table "colors_taxa", :id => false, :force => true do |t|
    t.integer "color_id"
    t.integer "taxon_id"
  end

  add_index "colors_taxa", ["taxon_id", "color_id"], :name => "index_colors_taxa_on_taxon_id_and_color_id"

  create_table "comments", :force => true do |t|
    t.integer  "user_id"
    t.integer  "parent_id"
    t.string   "parent_type"
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "comments", ["parent_type", "parent_id"], :name => "index_comments_on_parent_type_and_parent_id"
  add_index "comments", ["user_id"], :name => "index_comments_on_user_id"

  create_table "counties_simplified", :id => false, :force => true do |t|
    t.integer       "id"
    t.integer       "place_id"
    t.multi_polygon "geom",     :limit => nil
  end

  create_table "counties_simplified_01", :force => true do |t|
    t.integer       "place_geometry_id"
    t.integer       "place_id"
    t.multi_polygon "geom",              :limit => nil, :null => false
  end

  add_index "counties_simplified_01", ["geom"], :name => "index_counties_simplified_01_on_geom", :spatial => true
  add_index "counties_simplified_01", ["place_geometry_id"], :name => "index_counties_simplified_01_on_place_geometry_id"
  add_index "counties_simplified_01", ["place_id"], :name => "index_counties_simplified_01_on_place_id"

  create_table "counties_simplified_1", :id => false, :force => true do |t|
    t.integer       "id"
    t.integer       "place_id"
    t.multi_polygon "geom",     :limit => nil
  end

  create_table "countries_large_polygons", :id => false, :force => true do |t|
    t.integer  "id"
    t.integer  "place_id"
    t.geometry "geom",     :limit => nil
  end

  create_table "countries_simplified", :id => false, :force => true do |t|
    t.integer       "id"
    t.integer       "place_id"
    t.multi_polygon "geom",     :limit => nil
  end

  create_table "countries_simplified_1", :force => true do |t|
    t.integer       "place_geometry_id"
    t.integer       "place_id"
    t.multi_polygon "geom",              :limit => nil, :null => false
  end

  add_index "countries_simplified_1", ["geom"], :name => "index_countries_simplified_1_on_geom", :spatial => true
  add_index "countries_simplified_1", ["place_geometry_id"], :name => "index_countries_simplified_1_on_place_geometry_id"
  add_index "countries_simplified_1", ["place_id"], :name => "index_countries_simplified_1_on_place_id"

  create_table "custom_projects", :force => true do |t|
    t.text     "head"
    t.text     "side"
    t.text     "css"
    t.integer  "project_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "custom_projects", ["project_id"], :name => "index_custom_projects_on_project_id"

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "deleted_users", :force => true do |t|
    t.integer  "user_id"
    t.string   "login"
    t.string   "email"
    t.datetime "user_created_at"
    t.datetime "user_updated_at"
    t.integer  "observations_count"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "deleted_users", ["login"], :name => "index_deleted_users_on_login"
  add_index "deleted_users", ["user_id"], :name => "index_deleted_users_on_user_id"

  create_table "flags", :force => true do |t|
    t.string   "flag"
    t.string   "comment"
    t.datetime "created_at",                                      :null => false
    t.integer  "flaggable_id",                 :default => 0,     :null => false
    t.string   "flaggable_type", :limit => 15,                    :null => false
    t.integer  "user_id",                      :default => 0,     :null => false
    t.integer  "resolver_id"
    t.boolean  "resolved",                     :default => false
  end

  add_index "flags", ["user_id"], :name => "fk_flags_user"

  create_table "flickr_identities", :force => true do |t|
    t.string   "flickr_username"
    t.string   "frob"
    t.string   "token"
    t.datetime "token_created_at"
    t.integer  "auto_import",      :default => 0
    t.datetime "auto_imported_at"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "flickr_user_id"
  end

  create_table "friendships", :force => true do |t|
    t.integer  "user_id"
    t.integer  "friend_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "goal_contributions", :force => true do |t|
    t.integer  "contribution_id"
    t.string   "contribution_type"
    t.integer  "goal_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "goal_participant_id"
  end

  create_table "goal_participants", :force => true do |t|
    t.integer  "goal_id"
    t.integer  "user_id"
    t.integer  "goal_completed", :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "goal_rules", :force => true do |t|
    t.integer  "goal_id"
    t.string   "operator"
    t.string   "operator_class"
    t.string   "arguments"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "goals", :force => true do |t|
    t.text     "description"
    t.integer  "number_of_contributions_required"
    t.string   "goal_type"
    t.datetime "ends_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "completed",                        :default => false
  end

  create_table "identifications", :force => true do |t|
    t.integer  "observation_id"
    t.integer  "taxon_id"
    t.integer  "user_id"
    t.string   "type"
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "identifications", ["observation_id", "created_at"], :name => "index_identifications_on_observation_id_and_created_at"
  add_index "identifications", ["user_id", "created_at"], :name => "index_identifications_on_user_id_and_created_at"

  create_table "invites", :force => true do |t|
    t.integer  "user_id"
    t.string   "invite_address"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "list_rules", :force => true do |t|
    t.integer  "list_id"
    t.string   "operator"
    t.integer  "operand_id"
    t.string   "operand_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "list_rules", ["list_id"], :name => "index_list_rules_on_list_id"
  add_index "list_rules", ["operand_type", "operand_id"], :name => "index_list_rules_on_operand_type_and_operand_id"

  create_table "listed_taxa", :force => true do |t|
    t.integer  "taxon_id"
    t.integer  "list_id"
    t.integer  "last_observation_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "taxon_ancestor_ids"
    t.integer  "place_id"
    t.text     "description"
    t.integer  "comments_count",                          :default => 0
    t.integer  "user_id"
    t.integer  "updater_id"
    t.integer  "occurrence_status_level"
    t.string   "establishment_means",       :limit => 32
    t.integer  "first_observation_id"
    t.integer  "observations_count",                      :default => 0
    t.string   "observations_month_counts"
    t.integer  "taxon_range_id"
    t.integer  "source_id"
    t.boolean  "comprehensive",                           :default => false
    t.boolean  "manually_added",                          :default => false
  end

  add_index "listed_taxa", ["first_observation_id"], :name => "index_listed_taxa_on_first_observation_id"
  add_index "listed_taxa", ["last_observation_id"], :name => "index_listed_taxa_on_last_observation_id"
  add_index "listed_taxa", ["list_id", "taxon_ancestor_ids", "taxon_id"], :name => "index_listed_taxa_on_list_id_and_taxon_ancestor_ids_and_taxon_i"
  add_index "listed_taxa", ["list_id", "taxon_id"], :name => "index_listed_taxa_on_list_id_and_taxon_id"
  add_index "listed_taxa", ["list_id"], :name => "index_listed_taxa_on_list_id_and_lft"
  add_index "listed_taxa", ["place_id", "created_at"], :name => "index_listed_taxa_on_place_id_and_created_at"
  add_index "listed_taxa", ["place_id", "observations_count"], :name => "index_listed_taxa_on_place_id_and_observations_count"
  add_index "listed_taxa", ["place_id", "taxon_id"], :name => "index_listed_taxa_on_place_id_and_taxon_id"
  add_index "listed_taxa", ["source_id"], :name => "index_listed_taxa_on_source_id"
  add_index "listed_taxa", ["taxon_id"], :name => "index_listed_taxa_on_taxon_id"
  add_index "listed_taxa", ["taxon_range_id"], :name => "index_listed_taxa_on_taxon_range_id"
  add_index "listed_taxa", ["user_id"], :name => "index_listed_taxa_on_user_id"

  create_table "lists", :force => true do |t|
    t.string   "title"
    t.text     "description"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "type"
    t.boolean  "comprehensive",  :default => false
    t.integer  "taxon_id"
    t.datetime "last_synced_at"
    t.integer  "place_id"
    t.integer  "project_id"
    t.integer  "source_id"
  end

  add_index "lists", ["place_id"], :name => "index_lists_on_place_id"
  add_index "lists", ["project_id"], :name => "index_lists_on_project_id"
  add_index "lists", ["source_id"], :name => "index_lists_on_source_id"
  add_index "lists", ["type", "id"], :name => "index_lists_on_type_and_id"
  add_index "lists", ["user_id"], :name => "index_lists_on_user_id"

  create_table "observation_field_values", :force => true do |t|
    t.integer  "observation_id"
    t.integer  "observation_field_id"
    t.string   "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "observation_field_values", ["observation_field_id"], :name => "index_observation_field_values_on_observation_field_id"
  add_index "observation_field_values", ["observation_id"], :name => "index_observation_field_values_on_observation_id"

  create_table "observation_fields", :force => true do |t|
    t.string   "name"
    t.string   "datatype"
    t.integer  "user_id"
    t.string   "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "allowed_values"
  end

  add_index "observation_fields", ["name"], :name => "index_observation_fields_on_name"

  create_table "observation_photos", :force => true do |t|
    t.integer  "observation_id", :null => false
    t.integer  "photo_id",       :null => false
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "observation_photos", ["observation_id"], :name => "index_observation_photos_on_observation_id"
  add_index "observation_photos", ["photo_id"], :name => "index_observation_photos_on_photo_id"

  create_table "observations", :force => true do |t|
    t.date     "observed_on"
    t.text     "description"
    t.decimal  "latitude",                                        :precision => 15, :scale => 10
    t.decimal  "longitude",                                       :precision => 15, :scale => 10
    t.integer  "map_scale"
    t.text     "timeframe"
    t.string   "species_guess"
    t.integer  "user_id"
    t.integer  "taxon_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "place_guess"
    t.boolean  "id_please",                                                                       :default => false
    t.string   "observed_on_string"
    t.integer  "iconic_taxon_id"
    t.integer  "num_identification_agreements",                                                   :default => 0
    t.integer  "num_identification_disagreements",                                                :default => 0
    t.datetime "time_observed_at"
    t.string   "time_zone"
    t.boolean  "location_is_exact",                                                               :default => false
    t.boolean  "delta",                                                                           :default => false
    t.integer  "positional_accuracy"
    t.decimal  "private_latitude",                                :precision => 15, :scale => 10
    t.decimal  "private_longitude",                               :precision => 15, :scale => 10
    t.integer  "private_positional_accuracy"
    t.string   "geoprivacy"
    t.string   "quality_grade",                                                                   :default => "casual"
    t.point    "geom",                             :limit => nil
    t.string   "user_agent"
    t.string   "positioning_method"
    t.string   "positioning_device"
    t.boolean  "out_of_range"
    t.string   "license"
  end

  add_index "observations", ["geom"], :name => "index_observations_on_geom", :spatial => true
  add_index "observations", ["observed_on", "time_observed_at"], :name => "index_observations_on_observed_on_and_time_observed_at"
  add_index "observations", ["out_of_range"], :name => "index_observations_on_out_of_range"
  add_index "observations", ["quality_grade"], :name => "index_observations_on_quality_grade"
  add_index "observations", ["taxon_id", "user_id"], :name => "index_observations_on_taxon_id_and_user_id"
  add_index "observations", ["user_id", "observed_on", "time_observed_at"], :name => "index_observations_user_datetime"
  add_index "observations", ["user_id"], :name => "index_observations_on_user_id"

  create_table "observations_posts", :id => false, :force => true do |t|
    t.integer "observation_id", :null => false
    t.integer "post_id",        :null => false
  end

  add_index "observations_posts", ["observation_id"], :name => "index_observations_posts_on_observation_id"
  add_index "observations_posts", ["post_id"], :name => "index_observations_posts_on_post_id"

  create_table "passwords", :force => true do |t|
    t.integer  "user_id"
    t.string   "reset_code"
    t.datetime "expiration_date"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "photos", :force => true do |t|
    t.integer  "user_id"
    t.string   "native_photo_id"
    t.string   "square_url"
    t.string   "thumb_url"
    t.string   "small_url"
    t.string   "medium_url"
    t.string   "large_url"
    t.string   "original_url"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "native_page_url"
    t.string   "native_username"
    t.string   "native_realname"
    t.integer  "license"
    t.string   "type"
    t.string   "file_content_type"
    t.string   "file_file_name"
    t.integer  "file_file_size"
    t.boolean  "file_processing"
    t.boolean  "mobile",            :default => false
  end

  add_index "photos", ["native_photo_id"], :name => "index_flickr_photos_on_flickr_native_photo_id"

  create_table "picasa_identities", :force => true do |t|
    t.integer  "user_id"
    t.string   "token"
    t.datetime "token_created_at"
    t.string   "picasa_user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "picasa_identities", ["user_id"], :name => "index_picasa_identities_on_user_id"

  create_table "place_geometries", :force => true do |t|
    t.integer       "place_id"
    t.string        "source_name"
    t.string        "source_identifier"
    t.datetime      "created_at"
    t.datetime      "updated_at"
    t.multi_polygon "geom",              :limit => nil, :null => false
  end

  add_index "place_geometries", ["geom"], :name => "index_place_geometries_on_geom", :spatial => true
  add_index "place_geometries", ["place_id"], :name => "index_place_geometries_on_place_id"

  create_table "places", :force => true do |t|
    t.string   "name"
    t.string   "display_name"
    t.string   "code"
    t.decimal  "latitude",          :precision => 15, :scale => 10
    t.decimal  "longitude",         :precision => 15, :scale => 10
    t.decimal  "swlat",             :precision => 15, :scale => 10
    t.decimal  "swlng",             :precision => 15, :scale => 10
    t.decimal  "nelat",             :precision => 15, :scale => 10
    t.decimal  "nelng",             :precision => 15, :scale => 10
    t.integer  "woeid"
    t.integer  "parent_id"
    t.integer  "check_list_id"
    t.integer  "place_type"
    t.float    "bbox_area"
    t.string   "source_name"
    t.string   "source_identifier"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "delta",                                             :default => false
    t.integer  "user_id"
  end

  add_index "places", ["bbox_area"], :name => "index_places_on_bbox_area"
  add_index "places", ["check_list_id"], :name => "index_places_on_check_list_id"
  add_index "places", ["latitude", "longitude"], :name => "index_places_on_latitude_and_longitude"
  add_index "places", ["parent_id"], :name => "index_places_on_parent_id"
  add_index "places", ["place_type"], :name => "index_places_on_place_type"
  add_index "places", ["swlat", "swlng", "nelat", "nelng"], :name => "index_places_on_swlat_and_swlng_and_nelat_and_nelng"
  add_index "places", ["user_id"], :name => "index_places_on_user_id"

  create_table "posts", :force => true do |t|
    t.integer  "parent_id",    :null => false
    t.string   "parent_type",  :null => false
    t.integer  "user_id",      :null => false
    t.datetime "published_at"
    t.string   "title",        :null => false
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "posts", ["published_at"], :name => "index_posts_on_published_at"

  create_table "preferences", :force => true do |t|
    t.string   "name",       :null => false
    t.integer  "owner_id",   :null => false
    t.string   "owner_type", :null => false
    t.integer  "group_id"
    t.string   "group_type"
    t.string   "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "preferences", ["owner_id", "owner_type", "name", "group_id", "group_type"], :name => "index_preferences_on_owner_and_name_and_preference", :unique => true

  create_table "project_assets", :force => true do |t|
    t.integer  "project_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "asset_file_name"
    t.string   "asset_content_type"
    t.integer  "asset_file_size"
    t.datetime "asset_updated_at"
  end

  add_index "project_assets", ["asset_content_type"], :name => "index_project_assets_on_asset_content_type"
  add_index "project_assets", ["project_id"], :name => "index_project_assets_on_project_id"

  create_table "project_invitations", :force => true do |t|
    t.integer  "project_id"
    t.integer  "user_id"
    t.integer  "observation_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "project_invitations", ["observation_id"], :name => "index_project_invitations_on_observation_id"

  create_table "project_observations", :force => true do |t|
    t.integer  "project_id"
    t.integer  "observation_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "curator_identification_id"
  end

  add_index "project_observations", ["curator_identification_id"], :name => "index_project_observations_on_curator_identification_id"
  add_index "project_observations", ["observation_id"], :name => "index_project_observations_on_observation_id"
  add_index "project_observations", ["project_id"], :name => "index_project_observations_on_project_id"

  create_table "project_users", :force => true do |t|
    t.integer  "project_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "role"
    t.integer  "observations_count", :default => 0
    t.integer  "taxa_count",         :default => 0
  end

  add_index "project_users", ["project_id", "taxa_count"], :name => "index_project_users_on_project_id_and_taxa_count"
  add_index "project_users", ["user_id"], :name => "index_project_users_on_user_id"

  create_table "projects", :force => true do |t|
    t.integer  "user_id"
    t.string   "title"
    t.text     "description"
    t.text     "terms"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "icon_file_name"
    t.string   "icon_content_type"
    t.integer  "icon_file_size"
    t.datetime "icon_updated_at"
    t.string   "project_type"
    t.string   "cached_slug"
    t.integer  "observed_taxa_count", :default => 0
    t.datetime "featured_at"
    t.string   "source_url"
  end

  add_index "projects", ["cached_slug"], :name => "index_projects_on_cached_slug", :unique => true
  add_index "projects", ["source_url"], :name => "index_projects_on_source_url"
  add_index "projects", ["user_id"], :name => "index_projects_on_user_id"

  create_table "provider_authorizations", :force => true do |t|
    t.string   "provider_name", :null => false
    t.text     "provider_uid"
    t.text     "token"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "scope"
  end

  add_index "provider_authorizations", ["user_id"], :name => "index_provider_authorizations_on_user_id"

  create_table "quality_metrics", :force => true do |t|
    t.integer  "user_id"
    t.integer  "observation_id"
    t.string   "metric"
    t.boolean  "agree",          :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "quality_metrics", ["observation_id"], :name => "index_quality_metrics_on_observation_id"
  add_index "quality_metrics", ["user_id"], :name => "index_quality_metrics_on_user_id"

  create_table "roles", :force => true do |t|
    t.string "name"
  end

  create_table "roles_users", :id => false, :force => true do |t|
    t.integer "role_id"
    t.integer "user_id"
  end

  add_index "roles_users", ["role_id"], :name => "index_roles_users_on_role_id"
  add_index "roles_users", ["user_id"], :name => "index_roles_users_on_user_id"

  create_table "rules", :force => true do |t|
    t.string   "type"
    t.string   "ruler_type"
    t.integer  "ruler_id"
    t.string   "operand_type"
    t.integer  "operand_id"
    t.string   "operator"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "slugs", :force => true do |t|
    t.string   "name"
    t.integer  "sluggable_id"
    t.integer  "sequence",                     :default => 1, :null => false
    t.string   "sluggable_type", :limit => 40
    t.string   "scope"
    t.datetime "created_at"
  end

  add_index "slugs", ["name", "sluggable_type", "sequence", "scope"], :name => "index_slugs_on_n_s_s_and_s", :unique => true
  add_index "slugs", ["sluggable_id"], :name => "index_slugs_on_sluggable_id"

  create_table "sources", :force => true do |t|
    t.string   "in_text"
    t.text     "citation"
    t.string   "url"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "title"
    t.integer  "user_id"
  end

  add_index "sources", ["user_id"], :name => "index_sources_on_user_id"

  create_table "states_large_polygons", :id => false, :force => true do |t|
    t.integer  "id"
    t.integer  "place_id"
    t.geometry "geom",     :limit => nil
  end

  create_table "states_simplified", :id => false, :force => true do |t|
    t.integer       "id"
    t.integer       "place_id"
    t.multi_polygon "geom",     :limit => nil
  end

  create_table "states_simplified_1", :id => false, :force => true do |t|
    t.integer       "id"
    t.integer       "place_id"
    t.multi_polygon "geom",     :limit => nil
  end

  add_index "states_simplified_1", ["geom"], :name => "index_states_simplified_1_on_geom", :spatial => true

  create_table "taggings", :force => true do |t|
    t.integer  "tag_id"
    t.integer  "taggable_id"
    t.string   "taggable_type"
    t.datetime "created_at"
  end

  add_index "taggings", ["tag_id"], :name => "index_taggings_on_tag_id"
  add_index "taggings", ["taggable_id", "taggable_type"], :name => "index_taggings_on_taggable_id_and_taggable_type"

  create_table "tags", :force => true do |t|
    t.string "name"
  end

  create_table "taxa", :force => true do |t|
    t.string   "name"
    t.string   "rank"
    t.string   "source_identifier"
    t.string   "source_url"
    t.integer  "parent_id"
    t.integer  "source_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "iconic_taxon_id"
    t.boolean  "is_iconic",                             :default => false
    t.boolean  "auto_photos",                           :default => true
    t.boolean  "auto_description",                      :default => true
    t.integer  "version"
    t.string   "name_provider"
    t.boolean  "delta",                                 :default => false
    t.integer  "creator_id"
    t.integer  "updater_id"
    t.integer  "observations_count",                    :default => 0
    t.integer  "listed_taxa_count",                     :default => 0
    t.integer  "rank_level"
    t.string   "unique_name"
    t.text     "wikipedia_summary"
    t.string   "wikipedia_title"
    t.datetime "featured_at"
    t.string   "ancestry"
    t.integer  "conservation_status"
    t.integer  "conservation_status_source_id"
    t.boolean  "locked",                                :default => false, :null => false
    t.integer  "conservation_status_source_identifier"
  end

  add_index "taxa", ["ancestry"], :name => "index_taxa_on_ancestry"
  add_index "taxa", ["conservation_status_source_id"], :name => "index_taxa_on_conservation_status_source_id"
  add_index "taxa", ["featured_at"], :name => "index_taxa_on_featured_at"
  add_index "taxa", ["is_iconic"], :name => "index_taxa_on_is_iconic"
  add_index "taxa", ["listed_taxa_count"], :name => "index_taxa_on_listed_taxa_count"
  add_index "taxa", ["locked"], :name => "index_taxa_on_locked"
  add_index "taxa", ["name"], :name => "index_taxa_on_name"
  add_index "taxa", ["observations_count"], :name => "index_taxa_on_observations_count"
  add_index "taxa", ["parent_id"], :name => "index_taxa_on_parent_id"
  add_index "taxa", ["rank_level"], :name => "index_taxa_on_rank_level"
  add_index "taxa", ["unique_name"], :name => "index_taxa_on_unique_name", :unique => true

  create_table "taxon_links", :force => true do |t|
    t.string   "url",                                         :null => false
    t.string   "site_title"
    t.integer  "taxon_id",                                    :null => false
    t.boolean  "show_for_descendent_taxa", :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
  end

  add_index "taxon_links", ["taxon_id", "show_for_descendent_taxa"], :name => "index_taxon_links_on_taxon_id_and_show_for_descendent_taxa"
  add_index "taxon_links", ["user_id"], :name => "index_taxon_links_on_user_id"

  create_table "taxon_names", :force => true do |t|
    t.string   "name"
    t.boolean  "is_valid"
    t.string   "lexicon"
    t.string   "source_identifier"
    t.string   "source_url"
    t.integer  "taxon_id"
    t.integer  "source_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name_provider"
    t.integer  "creator_id"
    t.integer  "updater_id"
  end

  add_index "taxon_names", ["name"], :name => "index_taxon_names_on_name"
  add_index "taxon_names", ["taxon_id"], :name => "index_taxon_names_on_taxon_id"

  create_table "taxon_photos", :force => true do |t|
    t.integer  "taxon_id",   :null => false
    t.integer  "photo_id",   :null => false
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "taxon_photos", ["photo_id"], :name => "index_taxon_photos_on_photo_id"
  add_index "taxon_photos", ["taxon_id"], :name => "index_taxon_photos_on_taxon_id"

  create_table "taxon_ranges", :force => true do |t|
    t.integer       "taxon_id"
    t.string        "range_type"
    t.string        "source"
    t.integer       "start_month"
    t.integer       "end_month"
    t.datetime      "created_at"
    t.datetime      "updated_at"
    t.string        "range_content_type"
    t.string        "range_file_name"
    t.integer       "range_file_size"
    t.text          "description"
    t.integer       "source_id"
    t.multi_polygon "geom",               :limit => nil
    t.integer       "source_identifier"
  end

  add_index "taxon_ranges", ["geom"], :name => "index_taxon_ranges_on_geom", :spatial => true
  add_index "taxon_ranges", ["taxon_id"], :name => "index_taxon_ranges_on_taxon_id"

  create_table "taxon_versions", :force => true do |t|
    t.integer  "taxon_id"
    t.integer  "version"
    t.string   "name"
    t.string   "rank"
    t.string   "source_identifier"
    t.string   "source_url"
    t.integer  "parent_id"
    t.integer  "source_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "iconic_taxon_id"
    t.boolean  "is_iconic",         :default => false
    t.boolean  "auto_photos",       :default => true
    t.boolean  "auto_description",  :default => true
    t.integer  "lft"
    t.integer  "rgt"
    t.string   "name_provider"
    t.boolean  "delta",             :default => false
    t.integer  "creator_id"
    t.integer  "updater_id"
    t.integer  "rank_level"
  end

  create_table "users", :force => true do |t|
    t.string   "login",                     :limit => 40
    t.string   "name",                      :limit => 100
    t.string   "email",                     :limit => 100
    t.string   "crypted_password",          :limit => 40
    t.string   "salt",                      :limit => 40
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "remember_token",            :limit => 40
    t.datetime "remember_token_expires_at"
    t.string   "activation_code",           :limit => 40
    t.datetime "activated_at"
    t.string   "state",                                    :default => "passive"
    t.datetime "deleted_at"
    t.string   "time_zone"
    t.string   "description"
    t.string   "icon_file_name"
    t.string   "icon_content_type"
    t.integer  "icon_file_size"
    t.integer  "life_list_id"
    t.integer  "observations_count",                       :default => 0
    t.integer  "identifications_count",                    :default => 0
    t.integer  "journal_posts_count",                      :default => 0
    t.integer  "life_list_taxa_count",                     :default => 0
    t.text     "old_preferences"
    t.string   "icon_url"
    t.string   "last_ip"
  end

  add_index "users", ["identifications_count"], :name => "index_users_on_identifications_count"
  add_index "users", ["journal_posts_count"], :name => "index_users_on_journal_posts_count"
  add_index "users", ["life_list_taxa_count"], :name => "index_users_on_life_list_taxa_count"
  add_index "users", ["login"], :name => "index_users_on_login", :unique => true
  add_index "users", ["observations_count"], :name => "index_users_on_observations_count"
  add_index "users", ["state"], :name => "index_users_on_state"

end
