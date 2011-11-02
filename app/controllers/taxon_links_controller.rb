class TaxonLinksController < ApplicationController
  before_filter :login_required
  before_filter :load_taxon_link, :except => [:new, :create, :index]
  
  # NOTE: show and index should be deleted when we upgrade past Rails 2.2,
  # where we can use map.resources :taxon_links, :except => [:index, :show]
  def show; redirect_to @taxon_link.taxon; end
  def index; redirect_to taxa_path; end
  
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
