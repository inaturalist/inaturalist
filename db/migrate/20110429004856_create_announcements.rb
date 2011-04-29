class CreateAnnouncements < ActiveRecord::Migration
  def self.up
    create_table :announcements do |t|
      t.string :placement
      t.datetime :start
      t.datetime :end
      t.text :body

      t.timestamps
    end
  end

  def self.down
    drop_table :announcements
  end
end
