db = ActiveRecord::Base.connection.current_database
cmd = "psql #{db} < #{File.dirname(__FILE__)}/create_states_simplified.sql"
puts "running #{cmd}"
system cmd
