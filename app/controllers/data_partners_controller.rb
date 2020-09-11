class DataPartnersController < ApplicationController
  before_filter :admin_required
  before_filter :load_record, only: %w(show edit update destroy)

  layout "bootstrap-container"

  def index
    @data_partners = DataPartner.page( params[:page] ).per_page( 100 )
  end

  def new
    @data_partner = DataPartner.new
  end

  def create
    @data_partner = DataPartner.new( params[:data_partner] )
    if @data_partner.save
      redirect_to @data_partner
    else
      render :new
    end
  end

  def show    
  end

  def edit
  end

  def update
    @data_partner.assign_attributes( params[:data_partner] )
    if @data_partner.save
      redirect_to @data_partner
    else
      render :edit
    end
  end

  def destroy
    @data_partner.destroy
    flash[:notice] = "Data partner destroyed"
    redirect_back_or_default( data_partners_path )
  end
end
