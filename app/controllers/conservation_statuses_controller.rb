# frozen_string_literal: true

class ConservationStatusesController < ApplicationController
  before_action :curator_required
  before_action :load_record, except: [:new, :create, :index]
  before_action :load_taxon, except: [:create, :destroy]
  before_action :load_form_variables, only: [:new, :edit]

  layout "bootstrap"

  def index
    redirect_to taxon_path( @taxon, anchor: "status-tab" )
  end

  def new
    return render_404 unless @taxon

    @conservation_status = ConservationStatus.new( user: current_user, taxon: @taxon )
  end

  def create
    @conservation_status = ConservationStatus.new( approved_create_params )
    @conservation_status.user = current_user
    @conservation_status.updater = current_user
    if @conservation_status.save
      respond_to do | format |
        format.html do
          flash[:notice] = t( :conservation_status_created )
          redirect_to @conservation_status.taxon
        end
      end
      return
    end

    respond_to do | format |
      format.html do
        render :new
      end
    end
  end

  def edit
    render_404 unless @taxon
  end

  def update
    @conservation_status.updater = current_user
    if @conservation_status.update( approved_update_params )
      respond_to do | format |
        format.html do
          flash[:notice] = t( :conservation_status_updated )
          redirect_to @conservation_status.taxon
        end
      end
      return
    end

    respond_to do | format |
      format.html do
        render :new
      end
    end
  end

  def destroy
    if params[:conservation_status] && params[:conservation_status][:audit_comment]
      @conservation_status.audit_comment = params[:conservation_status][:audit_comment]
    end
    @conservation_status.destroy
    flash[:notice] = t( :conservation_status_deleted )
    redirect_to @conservation_status.taxon
  end

  private

  def approved_create_params
    params.require( :conservation_status ).permit(
      :audit_comment,
      :authority,
      :description,
      :geoprivacy,
      :iucn,
      :place_id,
      :status,
      :taxon_id,
      :url
    )
  end

  def approved_update_params
    params.require( :conservation_status ).permit(
      :audit_comment,
      :authority,
      :description,
      :geoprivacy,
      :iucn,
      :place_id,
      :status,
      :url
    )
  end

  def load_form_variables
    @conservation_status_authorities = ConservationStatus.
      group( :authority ).
      order( Arel.sql( "count(*) DESC" ) ).
      limit( 500 ).
      count.
      map( &:first ).compact.reject( &:blank? ).map( &:strip )
    @conservation_status_authorities += ConservationStatus::AUTHORITIES
    @conservation_status_authorities = @conservation_status_authorities.uniq.sort
  end

  def load_taxon
    @taxon = @conservation_status&.taxon || load_record( klass: "Taxon", param: :taxon_id )
  end
end
