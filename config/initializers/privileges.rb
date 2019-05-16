require "privileges"
ActiveRecord::Base.send( :include, Privileges )
ActionController::Base.send( :include, Privileges::Controller )
