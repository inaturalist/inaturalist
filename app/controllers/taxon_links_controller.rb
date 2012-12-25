class TaxonLinksController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_taxon_link, :except => [:new, :create, :index]

  def index
    @taxon_links = TaxonLink.order("taxon_links.id DESC").includes(:taxon, :place).page(params[:page])
  end
  
  def new
    @taxon = Taxon.find_by_id(params[:taxon_id].to_i) if params[:taxon_id]
    @taxon ||= Taxon.find_by_name('Life')
    @taxon_link = TaxonLink.new(:taxon => @taxon)
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
    @taxon_link.destroy
    respond_to do |format|
      format.html do
        flash[:notice] = "Taxon link deleted."
        return redirect_to @taxon_link.taxon
      end
    end
  end
  
  private
  
  def load_taxon_link
    render_404 unless @taxon_link = TaxonLink.find_by_id(params[:id])
  end
end
