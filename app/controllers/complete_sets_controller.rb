class CompleteSetsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :admin_required
  before_filter :find_complete_set, except: [ :new, :create ]
  layout "bootstrap"

  def new
    @complete_set = CompleteSet.new(:taxon_id => params[:taxon_id].to_i, :place_id => params[:place_id].to_i)
  end
  
  def edit
  end

  def show
    @taxa = @complete_set.get_taxa_for_place_taxon
  end

  def create
    @complete_set = CompleteSet.new(params[:complete_set])
    respond_to do |format|
      if @complete_set.save
        format.html { redirect_to(@complete_set, :notice => 'Complete Set was successfully created.') }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    respond_to do |format|
      if @complete_set.update_attributes(params[:complete_set])
        format.html { redirect_to(@complete_set, :notice => 'Complete Set was successfully updated.') }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def destroy
    @complete_set.destroy
    respond_to do |format|
      format.html { redirect_to(@complete_set.place) }
    end
  end
  
  private

  def find_complete_set
    begin
      @complete_set = CompleteSet.find(params[:id])
    rescue
      render_404
    end
  end
end