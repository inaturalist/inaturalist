class AddResolverIdResolvedMoveFlaggings < ActiveRecord::Migration
  def self.up
    
    add_column :flags, :resolver_id, :integer
    add_column :flags, :resolved, :boolean, :default=>false

    #sets resolved and resolver to true and the flagging user, respectively
    Flag.all.each do |flag|
      unless flag.comment.nil? or flag.comment.empty?
        flag.update_attributes!(:resolver_id=>flag.user.id, :resolved=>true)
      end
    end

    #moves the flagging content to the flags table
    if defined?(Flagging)    
      Flagging.all.each do |flagging|
        new_mappings = {
      	  :flag=>flagging.reason, 
       	  :comment=>flagging.resolution_note, 
          :created_at=>flagging.created_at, 
          :flaggable_id=>flagging.taxon_id, 
          :flaggable_type=>"Taxon", 
          :user_id=>flagging.user_id, 
          :resolver_id=>flagging.resolver_id, 
          :resolved=>flagging.resolved}
      	Flag.create(new_mappings)
      	flagging.destroy
      end
    
      drop_table :flaggings
    end
  end

  def self.down
    
    create_table :flaggings do |t|
      t.integer :user_id          # someone's gotta do the flagging
      t.integer :taxon_id         # taxon being flagged
      t.string  :reason           # why is this thing being flagged?
      t.integer :resolver_id      # someone's gotta do the resolving
      t.boolean :resolved, :default => false
      t.string :resolution_note  # quick note about why it was resolved
      t.timestamps
    end
    
    Flag.all.each do |flagging|
      if flagging.flaggable_type == "Taxon"
        new_mappings = {
          :reason=>flagging.flag, 
          :resolution_note=>flagging.comment, 
          :created_at=>flagging.created_at, 
          :taxon_id=>flagging.flaggable_id, 
          :user_id=>flagging.user_id, 
          :resolver_id=>flagging.resolver_id, 
          :resolved=>flagging.resolved}
        Flagging.create(new_mappings)
        flagging.destroy
      end
    end
    
    remove_column :flags, :resolver_id
    remove_column :flags, :resolved
  end
end
