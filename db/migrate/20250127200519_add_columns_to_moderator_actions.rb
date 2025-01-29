# frozen_string_literal: true

class AddColumnsToModeratorActions < ActiveRecord::Migration[6.1]
  def up
    add_column :moderator_actions, :resource_user_id, :integer
    add_column :moderator_actions, :resource_parent_id, :integer
    add_column :moderator_actions, :resource_parent_type, :string
    add_column :moderator_actions, :resource_content, :text

    ModeratorAction.includes( :resource ).find_in_batches( batch_size: 500 ) do | batch |
      ModeratorAction.transaction do
        batch.each do | moderator_action |
          next unless moderator_action.resource

          updates = {}
          if ( user = Flag.instance_user( moderator_action.resource ) )
            updates[:resource_user_id] = user.id
          end
          if ( resource_content = Flag.instance_content( moderator_action.resource ) )
            updates[:resource_content] = resource_content
          end
          if ( resource_parent = Flag.instance_parent( moderator_action.resource ) )
            updates[:resource_parent_type] = resource_parent&.class&.polymorphic_name
            updates[:resource_parent_id] = resource_parent&.id
          end
          next if updates.blank?

          # use update_columns to make sure these columns are retroactively
          # populated even if the records are no longer valid, e.g. if the
          # moderating user has since been deleted
          moderator_action.update_columns( updates )
        end
      end
    end
  end

  def down
    remove_column :moderator_actions, :resource_user_id
    remove_column :moderator_actions, :resource_parent_id
    remove_column :moderator_actions, :resource_parent_type
    remove_column :moderator_actions, :resource_content
  end
end
