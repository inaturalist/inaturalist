# frozen_string_literal: true

module Admin
  class QueriesController < ApplicationController
    before_action :authenticate_user!
    before_action :admin_required
    prepend_around_action :enable_replica_and_release_context, only: :replica
    before_action :inat_queries_enabled_required, only: [:inat, :kill]

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

    def inat
      @queries = inat_queries
      render "admin/queries/inat", layout: "admin"
    end

    # Terminate a backend, in practice a hand-run session against staging.
    # Matching and signalling the pid in one statement leaves no window for
    # Postgres to recycle it onto an unrelated backend
    def kill
      pid = params[:pid].to_i

      connection = ActiveRecord::Base.connection
      result = connection.execute( <<-SQL.squish )
        SELECT pg_terminate_backend( pid )
        FROM pg_stat_activity
        WHERE pid = #{pid}
          AND usename = #{connection.quote( CONFIG.inat_usename )}
          AND client_addr = #{connection.quote( CONFIG.inat_client_addr )}::inet
          AND backend_type = 'client backend'
      SQL

      # no rows means the conditions matched nothing, so nothing was killed
      if result.ntuples.positive?
        flash[:notice] = "Killed query #{pid}"
      else
        flash[:error] = "No killable query with pid #{pid}"
      end
      redirect_to inat_admin_queries_path
    rescue ActiveRecord::StatementInvalid => e
      flash[:error] = "Could not kill query #{pid}: #{e.message}"
      redirect_to inat_admin_queries_path
    end

    private

    # the page does not exist where it has not been configured, so there is no
    # route to advertise and nothing to explain
    def inat_queries_enabled_required
      render_404 unless helpers.inat_queries_enabled?
    end

    # Sessions opened by hand, in practice psql and rails consoles against
    # staging, which all share one database user and address. See config.yml.
    # Display only, kill repeats these conditions in SQL
    def inat_queries
      active_queries( :primary ).select do | q |
        q["usename"] == CONFIG.inat_usename &&
          q["client_addr"] == CONFIG.inat_client_addr &&
          q["backend_type"] == "client backend"
      end
    end

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
end
