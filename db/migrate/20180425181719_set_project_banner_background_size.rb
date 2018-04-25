class SetProjectBannerBackgroundSize < ActiveRecord::Migration
  def up
    scope = Project.
      where(project_type: ["collection", "umbrella"]).
      where("cover_file_name IS NOT NULL")
    scope.each do |p|
      p.update_attributes(preferred_banner_contain: true)
    end
    Project.elastic_index!(scope: scope)
  end

  def down
    # irreversible
  end
end
