class CreateTableForDelayedJob < ActiveRecord::Migration
  def self.up
    create_table :delayed_jobs, :force => true do |t|
      t.integer  :priority, :default => 0
      t.integer  :attempts, :default => 0
      t.text     :handler
      t.text     :last_error
      t.datetime :run_at
      t.datetime :locked_at
      t.datetime :failed_at
      t.string   :locked_by
      t.timestamps
    end
  end

  def self.down
    drop_table :delayed_jobs
  end

end
