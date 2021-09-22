class AddResolvedAtAndFlaggableUserIdToFlags < ActiveRecord::Migration
  def up
    add_column :flags, :resolved_at, :datetime
    add_column :flags, :flaggable_user_id, :integer
    Flag::TYPES.each do |model_name|
      if model_name == "User"
        say "Updating flags on User..."
        execute <<-SQL
          UPDATE flags SET flaggable_user_id = flaggable_id WHERE flaggable_type = 'User'
        SQL
        next
      end
      klass = model_name.constantize
      k, reflection = if model_name == "Message"
        klass.reflections.detect{|r| r[0] == "from_user" }
      else
        klass.reflections.detect{|r| r[1].class_name == "User" && r[1].macro == :belongs_to }
      end
      if reflection
        say "Updating flags on #{model_name}..."
        execute <<-SQL
          UPDATE flags
          SET flaggable_user_id = u.id
          FROM users u, #{klass.table_name} a
          WHERE
            flags.flaggable_type = '#{model_name}'
            AND flags.flaggable_id = a.id
            AND u.id = a.#{reflection.foreign_key}
        SQL
      end
    end
  end
  def down
    remove_column :flags, :resolved_at
    remove_column :flags, :flaggable_user_id
  end
end
