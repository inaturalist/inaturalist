# frozen_string_literal: true

class Admin::QueriesController < ApplicationController
  before_action :authenticate_user!
  before_action :admin_required
  prepend_around_action :enable_replica_and_release_context, only: :replica

  def index
    redirect_to :primary_admin_queries
  end

  def primary
    @source = :primary
    @queries = active_queries( :primary )
    render "admin/queries/queries_table", layout: "admin"
  end

  def replica
    @source = :replica
    @queries = active_queries( :replica )
    render "admin/queries/queries_table", layout: "admin"
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
      q["duration"] = q["query_start"] ? ( now - q["query_start"] ) * 1000.0 : 0
    end

    queries.sort_by {| q | q["duration"] }.reverse
  end

  def enable_replica_and_release_context
    begin
      ActiveRecord::Base.connection.enable_replica
      Makara::Context.release_all
      yield
    rescue Makara::Errors::AllConnectionsBlacklisted
      yield
    ensure
      ActiveRecord::Base.connection.disable_replica
    end
  end
end
