# frozen_string_literal: true

class Admin::QueriesController < ApplicationController
  def index
    redirect_to :primary_admin_queries
  end

  def primary
    @queries = active_queries( :primary )
    render layout: "admin"
  end

  def replica
    @queries = active_queries( :replica )
    render layout: "admin"
  end

  private

  def active_queries( type )
    pool = ActiveRecord::Base.connection.instance_variable_get( "@#{type}_pool" )
    queries = []

    pool&.connections&.each do | connection |
      queries += connection.active_queries.map do | q |
        { db_host: connection.config[:host] }.merge( q )
      end
    end

    queries.delete_if {| q | q["query"] =~ /pg_stat_activity/ }

    now = Time.current
    queries.each do | q |
      q["duration"] = q["query_start"] ? ( now - q["query_start"] ) / 1000.0 : 0
    end

    queries.sort_by {| q | q["duration"] }.reverse
  end
end
