require "privileges"
ActiveRecord::Base.send( :include, Privileges )
