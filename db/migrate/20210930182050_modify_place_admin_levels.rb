class ModifyPlaceAdminLevels < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!
  def up
    # Removing user updates from migration to run separately
    #
    # max_id = User.maximum( :id )
    # batch_size = 1000
    # batch_count = ( max_id / batch_size )
    # for batch_index in ( 0..batch_count ) do
    #   start_id = batch_index * batch_size
    #   puts start_id
    #   User.where( "id > ? AND id <= ?", start_id, start_id + batch_size )
    #     .update_all( "lat_lon_acc_admin_level = lat_lon_acc_admin_level * 10" )
    # end

    max_id = Place.maximum( :id ) || 0
    batch_size = 10000
    batch_count = ( max_id / batch_size )
    for batch_index in ( 0..batch_count ) do
      start_id = batch_index * batch_size
      puts start_id
      Place.where( "id > ? AND id <= ?", start_id, start_id + batch_size )
        .update_all( "admin_level = admin_level * 10" )
    end
  end

  def down
    # Removing user updates from migration to run separately
    #
    # max_id = User.maximum( :id )
    # batch_size = 1000
    # batch_count = ( max_id / batch_size )
    # for batch_index in ( 0..batch_count ) do
    #   start_id = batch_index * batch_size
    #   puts start_id
    #   User.where( "id > ? AND id <= ?", start_id, start_id + batch_size )
    #     .update_all( "lat_lon_acc_admin_level = lat_lon_acc_admin_level / 10" )
    # end

    max_id = Place.maximum( :id ) || 0
    batch_size = 10000
    batch_count = ( max_id / batch_size )
    for batch_index in ( 0..batch_count ) do
      start_id = batch_index * batch_size
      puts start_id
      Place.where( "id > ? AND id <= ?", start_id, start_id + batch_size )
        .update_all( "admin_level = admin_level / 10" )
    end
  end
end
