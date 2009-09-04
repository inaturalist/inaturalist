Acts As Flaggable
=================

Allows for flags to be added to multiple and different models.

== Resources

Install
 * Run the following command:
 
 script/plugin install http://svn.baconbear.com/rails_plugins/acts_as_flaggable
 
 * Create a new rails migration and add the following self.up and self.down methods
 
 def self.up
   create_table :flags, :force => true do |t|
     t.column :flag, :string, :default => ""
     t.column :comment, :string, :default => ""
     t.column :created_at, :datetime, :null => false
     t.column :flaggable_id, :integer, :default => 0, :null => false
     t.column :flaggable_type, :string, :limit => 15,
       :default => "", :null => false
     t.column :user_id, :integer, :default => 0, :null => false
   end

   add_index :flags, ["user_id"], :name => "fk_flags_user"
 end

 def self.down
   drop_table :flags
 end

== Usage
 
 * Make you ActiveRecord model act as flaggable.
 
 class Model < ActiveRecord::Base
 	acts_as_flaggable
 end
 
 * Add a flag to a model instance
 
 model = Model.new
 flag = Flag.new
 flag.flag = 'Some flag'
 model.flags.add_flag flag

 * When a flag is added via add_flag, flagged(flag, flag_count) is called
   on the flaggable model.  This allows the model to perform certain
   operations if the number of flags reaches a certain point.  For example,
   you may want to mark a Post as deleted if a Post receives too many "spam"
   flags
 
 * Each flag reference flaggable object
 
 model = Model.find(1)
 model.flags.get(0).commtable == model

== Credits

Juixe - This plugin is a lightly modified version of Acts As Commentable.  As you'll
        see from the source, it's almost completely a search/replace job with some small
        modifications

Xelipe - Acts as Commentable was heavily influenced by Acts As Taggable.

== More

Acts as commentable
http://www.juixe.com/techknow/index.php/2006/06/18/acts-as-commentable-plugin/
http://www.juixe.com/projects/acts_as_commentable
