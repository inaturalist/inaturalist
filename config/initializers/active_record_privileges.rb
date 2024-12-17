# frozen_string_literal: true

require "privileges"

ActiveRecord::Base.include( Privileges )
ActionController::Base.include( Privileges::Controller )
