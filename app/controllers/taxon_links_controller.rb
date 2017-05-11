class TaxonLinksController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_taxon_link, except: [:new, :create, :index]
  before_filter :curator_required, only: [:new, :create, :edit, :update, :destroy]

  def index
    @taxon_links = TaxonLink.order("taxon_links.id DESC").includes(:taxon, :place).page(params[:page])
  end
  
  def new
    @taxon = Taxon.find_by_id(params[:taxon_id].to_i) if params[:taxon_id]
    @taxon ||= Taxon.find_by_name('Life')
    @taxon_link = TaxonLink.new(:taxon => @taxon)
  end

  def show
    respond_to do |format|
      format.html { redirect_to edit_taxon_link_path( params[:id] ) }
    end
  end
  
  def create
    @taxon_link = TaxonLink.new(params[:taxon_link])
    @taxon_link.user = current_user
    respond_to do |format|
      if @taxon_link.save
        format.html do
          flash[:notice] = "Taxon link saved."
          return redirect_to @taxon_link.taxon
        end
      else
        flash.now[:error] = "Taxon link had errors: #{@taxon_link.errors.full_messages.to_sentence}"
        format.html { render :action => :new }
      end
    end
  end

  def edit
    @taxon = @taxon_link.taxon
  end

  def update
    respond_to do |format|
      if @taxon_link.update_attributes(params[:taxon_link])
        format.html do
          flash[:notice] = "Taxon link updated."
          return redirect_to @taxon_link.taxon
        end
      else
        format.html { render :action => :edit }
      end
    end
  end

  def destroy
    unless @taxon_link.deletable_by?( current_user )
      respond_to do |format|
        format.html do
          flash[:error] = I18n.t( :you_dont_have_permission_to_do_that )
          return redirect_back_or_default( @taxon_link )
        end
      end
    end
    @taxon_link.destroy
    respond_to do |format|
      format.html do
        flash[:notice] = "Taxon link deleted."
        redirect_to @taxon_link.taxon
      end
    end
  end
  
  private
  
  def load_taxon_link
    render_404 unless @taxon_link = TaxonLink.find_by_id(params[:id])
  end
end
