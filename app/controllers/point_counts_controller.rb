# frozen_string_literal: true

class PointCountsController < ApplicationController
  layout "point_counts"
  # This HTML-only workflow always requires CSRF protection, including requests
  # with an Authorization header (the application permits some API exceptions).
  skip_before_action :verify_authenticity_token
  protect_from_forgery with: :exception
  skip_before_action :set_ga_trackers
  before_action :private_response
  before_action :authenticate_user!
  before_action :html_only
  before_action :load_workflow
  before_action :load_event, except: [:index, :new, :create]
  rescue_from Surveys::PointCount::Invalid, ActiveRecord::RecordInvalid, with: :invalid_submission
  rescue_from ActiveRecord::StatementInvalid, with: :conflicting_submission
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def index
    @events = @workflow.events.includes( :survey_sampling_unit ).order( created_at: :desc ).
      page( params[:page] ).per_page( 20 )
  end

  def new
    @stations = @workflow.stations.order( :name )
    @protocol = Surveys::PointCountProtocol.version
  end

  def create
    event = @workflow.create( fields( :station_uuid, :station_name, :station_latitude, :station_longitude ) )
    redirect_to edit_point_count_path( event.uuid ), notice: "Visit created. Record your effort and detections."
  end

  def show
    @values = Surveys::PointCount.values( @event )
  end

  def edit
    return redirect_to point_count_path( @event.uuid ) unless %w(planned in_progress).include?( @event.status )

    @values = Surveys::PointCount.values( @event )
    @taxa = [Surveys::PointCountProtocol.birds]
    if params[:q].present?
      query = "%#{Taxon.sanitize_sql_like( params[:q].to_s[0, 100] )}%"
      @taxa += Surveys::PointCountProtocol.bird_taxa.joins( :taxon_names ).
        where( "taxa.name ILIKE :q OR taxon_names.name ILIKE :q", q: query ).distinct.order( :name ).limit( 25 ).to_a
    end
    @taxa.uniq!
  end

  def update
    @workflow.update( @event.uuid, fields( :started_at, :ended_at, :time_zone, :remarks,
      :method_followed, :all_detections_reported, :deviation_reason, :precipitation, :wind, :noise ) )
    redirect_to edit_point_count_path( @event.uuid ), notice: "Effort and assessment saved."
  end

  def add_detection
    @workflow.add_detection( @event.uuid, fields( :taxon_id, :quantity, :detection_method, :remarks, :observation_id ) )
    redirect_to edit_point_count_path( @event.uuid ), notice: "Detection added."
  end

  def remove_detection
    @workflow.remove_detection( @event.uuid, params[:detection_uuid] )
    redirect_to edit_point_count_path( @event.uuid ), notice: "Detection removed; the source observation is unchanged."
  end

  def complete
    @workflow.complete( @event.uuid )
    redirect_to point_count_path( @event.uuid ), notice: "Visit completed. Scientific results are now frozen."
  end

  def void
    @workflow.void( @event.uuid, fields( :reason )["reason"] )
    redirect_to point_count_path( @event.uuid ), notice: "Visit voided. Its history is retained."
  end

  private

  def private_response
    response.headers["Cache-Control"] = "no-store, private"
    response.headers["Referrer-Policy"] = "same-origin"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end

  def html_only
    head :not_acceptable unless request.format.html?
  end

  def load_workflow
    @workflow = Surveys::PointCount.new( current_user )
  end

  def load_event
    @event = @workflow.events.find_by!( uuid: params[:id] )
  end

  # ApplicationController permits all parameters for legacy controllers; slice
  # explicitly here, including when the supplied parameters are already permitted.
  def fields( *keys )
    params.require( :point_count ).slice( *keys ).permit( *keys ).to_h
  end

  def invalid_submission( error )
    @error = error.is_a?( ActiveRecord::RecordInvalid ) ? error.record.errors.full_messages.to_sentence : error.message
    render :error, status: :unprocessable_entity
  end

  def conflicting_submission( _error )
    @error = "This change conflicts with the saved survey. Reload the visit and check its status and values."
    render :error, status: :unprocessable_entity
  end

  def not_found
    head :not_found
  end
end
