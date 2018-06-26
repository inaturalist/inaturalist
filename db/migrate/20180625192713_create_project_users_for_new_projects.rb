class CreateProjectUsersForNewProjects < ActiveRecord::Migration
  def up
    # Subscriptions to projects where users are not also ProjectUsers.
    # Outside of new-style projects (collections and umbrellas) users
    # cannot directly subscribe to projects, so these should only be
    # that have "followed" the new-style projects, which we will now
    # convert to ProjectUsers
    Subscription.
      joins("LEFT JOIN project_users ON (subscriptions.resource_id=project_users.project_id AND subscriptions.user_id=project_users.user_id)").
      where(resource_type: "Project").
      where("project_users.user_id IS NULL").each do |s|

      pu = ProjectUser.new(project_id: s.resource_id, user_id: s.user_id)
      # set the most conservative option for coordinate access, even
      # though that preference won't be used for new-style projects right now
      pu.prefers_curator_coordinate_access = "none"
      pu.save
    end
  end

  def down
  end
end
