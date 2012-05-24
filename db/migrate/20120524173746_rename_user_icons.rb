class RenameUserIcons < ActiveRecord::Migration
  def self.up
    User.find_each do |user|
      next unless user.icon.file?
      new_path = ""
      move_failed = false
      (user.icon.styles.keys+[:original]).each do |style|
        new_path = user.icon.path(style)
        old_path = new_path.sub(/#{user.id}\-.*$/, "#{user.id}/#{style}/#{user.icon_file_name}")
        
        # for some reason a lot of openid stuff has a trailing dot
        old_path = "#{old_path}." unless File.exist?(old_path)
        
        begin
          FileUtils.move(old_path, new_path)
          move_failed = false
        rescue => e
          puts "Failed to move #{old_path} to #{new_path}: #{e}"
          move_failed = true
        end
      end
      
      # remove the old dir
      FileUtils.rm_rf(new_path[/^.+?#{user.id}/, 0]) unless move_failed
      
      new_file_name = new_path[/#{user.id}\-.*$/, 0]

      user.icon_file_name = new_file_name
      user.save
    end
  end

  def self.down
    # there is no going back!
  end
end
