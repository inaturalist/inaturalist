class CreateObservationReviews < ActiveRecord::Migration
  def up
    create_table :observation_reviews do |t|
      t.references :user
      t.references :observation
      t.boolean :reviewed, default: true
      t.boolean :user_added, default: false
      t.timestamps null: false
    end
    ActiveRecord::Base.connection.execute("
      INSERT INTO observation_reviews
        (user_id, observation_id, reviewed, user_added, created_at, updated_at)
      SELECT user_id, observation_id, 't', 'f', MIN(created_at), MAX(updated_at)
      FROM identifications
      GROUP BY observation_id, user_id
      ORDER BY observation_id asc")
    add_index :observation_reviews, [ :observation_id, :user_id ], unique: true
    add_index :observation_reviews, :user_id
  end

  def down
    drop_table :observation_reviews
  end
end
