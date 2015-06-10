# Load all media clases so descendants are always available
Dir.glob(File.join(Rails.root, 'app', 'models', '*_photo.rb')).each do |path|
  require_dependency path
end
Dir.glob(File.join(Rails.root, 'app', 'models', '*_sound.rb')).each do |path|
  require_dependency path
end
