# frozen_string_literal: true

class Admin
  class DelayedJobsController < ApplicationController
    before_action :authenticate_user!
    before_action :admin_required

    layout "admin"

    def index
      redirect_to :active_admin_delayed_jobs
    end

    def active
      @jobs = Delayed::Job.possibly_active
    end

    def failed
      @jobs = Delayed::Job.failed.limit( 100 )
    end

    def pending
      @jobs = Delayed::Job.pending.limit( 100 )
    end

    def unlock
      if params[:id]
        delayed_job = Delayed::Job.find_by_id( params[:id] )
        delayed_job&.update( locked_by: nil, locked_at: nil )
      end
      redirect_to :active_admin_delayed_jobs
    end
  end
end
