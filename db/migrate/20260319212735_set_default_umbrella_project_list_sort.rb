# frozen_string_literal: true

class SetDefaultUmbrellaProjectListSort < ActiveRecord::Migration[6.1]
  def up
    umbrellas = Project.umbrella.all.each do | project |
      next unless project.prefers_umbrella_project_list_sort.nil?

      project.skip_indexing = true

      project.prefers_umbrella_project_list_sort = "descending"
      project.save
    end

    Project.elastic_index!( ids: umbrellas.pluck( :id ), delay: true )
  end

  def down
    # irreversible
  end
end
