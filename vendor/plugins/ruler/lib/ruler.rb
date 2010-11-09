# Load files in app/ into the load path
%w{ models }.each do |dir|
  path = File.join(File.dirname(__FILE__), 'app', dir)
  $LOAD_PATH << path
  ActiveSupport::Dependencies.autoload_paths << path
  
  # Remove from load_once_paths so changes always show up...
  ActiveSupport::Dependencies.autoload_once_paths.delete(path)
end

