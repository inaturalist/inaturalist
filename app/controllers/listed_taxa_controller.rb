class ListedTaxaController < ApplicationController
  before_filter :authenticate_user!, :except => [:show]
  before_filter :load_listed_taxon, :except => [:index, :create, :refresh_observationcounts]

  SHOW_PARTIALS = %w(place_tip guide batch_edit_row)

  def index
    redirect_to lists_path
  end
  
  def show
    respond_to do |format|
      format.html do
        if !@list.is_a?(CheckList) && @list.show_obs_photos
          @photo = @listed_taxon.first_observation.photos.first if @listed_taxon.first_observation
          @photo ||= @listed_taxon.last_observation.photos.first if @listed_taxon.last_observation
        end
        @photo ||= @listed_taxon.taxon.taxon_photos.order(:id).first.try(:photo)
        if @list.is_a?(CheckList)
          @related_listed_taxa = @listed_taxon.related_listed_taxa
          @primary_listed_taxon = @listed_taxon.primary_listed_taxon
        end
        if partial = params[:partial]
          partial = "lists/listed_taxon" unless SHOW_PARTIALS.include?(partial)
          render :partial => partial, :layout => false
          return
        end
      end
      format.json { render :json => @listed_taxon }
    end
  end
  
  def create
    if params[:listed_taxon]
      @list = List.find_by_id(params[:listed_taxon][:list_id].to_i)
      @place = Place.find_by_id(params[:listed_taxon][:place_id].to_i) if params[:listed_taxon][:place_id]
      @taxon = Taxon.find_by_id(params[:listed_taxon][:taxon_id].to_i)
    else
      @list = List.find_by_id(params[:list_id].to_i)
      @place = Place.find(params[:place_id]) rescue nil
      @taxon = Taxon.find_by_id(params[:taxon_id].to_i)
    end
    @list ||= @place.check_list if @place
    
    unless @list && @list.listed_taxa_editable_by?(current_user)
      msg = "Sorry, you don't have permission to add to this list."
      respond_to do |format|
        format.html do
          flash[:notice] = msg
          redirect_to lists_path
        end
        format.json do
          render :json => {
              :object => @listed_taxon,
              :errors => msg,
              :full_messages => msg
            },
            :status => :unprocessable_entity,
            :status_text => msg
        end
      end
      return
    end

    opts = params[:listed_taxon] || {}
    opts[:user_id] = current_user.id
    opts[:manually_added] = true
    opts.delete(:taxon_id)
    opts.delete(:force_trickle_down_establishment_means) unless current_user.is_curator?
    
    @listed_taxon = @list.add_taxon(@taxon, opts)
    
    respond_to do |format|
      format.html do
        if @listed_taxon.valid?
          flash[:notice] = t(:list_updated)
        else
          flash[:error] = "D'oh, there was a problem updating your list: " +
                          @listed_taxon.errors.full_messages.join(', ')
        end
        return redirect_to lists_path if @listed_taxon.list_id.nil?
        redirect_to list_path(@listed_taxon.list)
      end
      format.json do
        partial = 'lists/' + (params[:partial] || 'listed_taxon')
        if @listed_taxon.valid?
          render(:json => {
            :instance => @listed_taxon,
            :extra => {
              :taxon => @listed_taxon.taxon,
              :iconic_taxon => @listed_taxon.taxon.iconic_taxon,
              :place => @listed_taxon.place
            },
            :html => view_context.render_in_format(:html,
              :partial => partial, 
              :object => @listed_taxon,
              :locals => {:listed_taxon => @listed_taxon, :seenit => true}
            )
          })
        else
          render(
            :json => {
              :object => @listed_taxon,
              :errors => @listed_taxon.errors,
              :full_messages => @listed_taxon.errors.full_messages.to_sentence
            },
            :status => :unprocessable_entity,
            :status_text => @listed_taxon.errors.full_messages.join(', ')
          )
        end
      end
    end
  end
  
  def update
    unless @list.listed_taxa_editable_by?(current_user)
      flash[:error] = "You don't have permission to edit listed taxa on this list"
      redirect_to :back
      return
    end
    
    listed_taxon = params[:listed_taxon] || {}

    respond_to do |format|
      @listed_taxon.update_attributes_and_primary(listed_taxon, current_user)
      if @listed_taxon.valid?
        format.html do
          flash[:notice] = t(:listed_taxon_updated)
          redirect_to :back
        end
        format.json do
          if params[:partial] && SHOW_PARTIALS.include?(params[:partial])
            @listed_taxon.html = view_context.render_in_format(:html, :partial => "lists/#{params[:partial]}", 
              :object => @listed_taxon)
          end
          render :json => @listed_taxon.to_json(:methods => [:errors, :html])
        end
      else
        format.html do
          Rails.logger.debug "[DEBUG] @listed_taxon.errors.full_messages: #{@listed_taxon.errors.full_messages.inspect}"
          flash[:error] = "There were problems updating that listed taxon: #{@listed_taxon.errors.full_messages.to_sentence}"
          redirect_to :back
        end
        format.json do
          render :status => :unprocessable_entity, :json => @listed_taxon.as_json(:methods => [:errors])
        end
      end
    end
  end

  def destroy
    @listed_taxon = ListedTaxon.where(id: params[:id]).includes(:list).first
    
    unless @listed_taxon && @listed_taxon.removable_by?(current_user)
      msg = "Sorry, you don't have permission to delete from this list."
      respond_to do |format|
        format.html do
          flash[:notice] = msg
          return redirect_to lists_path
        end
        format.json do
          return render(:json => {:error => msg})
        end
      end
    end
    
    @listed_taxon.destroy
    
    respond_to do |format|
      format.html do
        flash[:notice] = t(:taxon_removed_from_list)
        return redirect_to(@listed_taxon.list)
      end
      format.json do
        if params[:partial]
          partial = "lists/#{params[:partial]}.html.erb"
          return render(
            :json => {
              :object => @listed_taxon,
              :html => render_to_string(:partial => partial, :locals => {
                :listed_taxon => @listed_taxon
              })
            }
          )
        else
          return render(:json => @listed_taxon)
        end
      end
    end
  end
  
  def refresh_observationcounts
    @listed_taxon = ListedTaxon.find_by_id(params[:listed_taxon_id])
    @listed_taxon.force_update_cache_columns = true
    respond_to do |format|
      if @listed_taxon.save
        format.html do
          flash[:notice] = t(:observationcounts_refreshed)
          redirect_to @listed_taxon
        end
      end
    end
  end
  
  private
  
  def load_listed_taxon
    @listed_taxon = ListedTaxon.where(id: params[:id]).includes([ :list, :taxon, :user ]).first
    unless @listed_taxon
      msg = "That listed taxon doesn't exist."
      respond_to do |format|
        format.html do
          flash[:notice] = msg
          redirect_back_or_default('/')
        end
        format.json { render :status => :unprocessable_entity, :json => {:error => msg} }
      end
      return
    end
    @list = @listed_taxon.list
    @taxon = @listed_taxon.taxon
  end
end
