class RenameUserIcons < ActiveRecord::Migration
  def self.up
    User.find_each do |user|
      next unless user.icon.file?
      new_path = ""
      (user.icon.styles.keys+[:original]).each do |style|
        new_path = user.icon.path(style)
        old_path = new_path.sub(/#{user.id}\-.*$/, "#{user.id}/#{style}/#{user.icon_file_name}")
        FileUtils.move(old_path, new_path)
      end
      
      # remove the old dir
      FileUtils.rm_rf(new_path[/^.+?#{user.id}/, 0])
      
      new_file_name = new_path[/#{user.id}\-.*$/, 0]

      user.icon_file_name = new_file_name
      user.save
    end
  end

  def self.down
    # there is no going back!
  end
end
