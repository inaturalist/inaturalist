class ListedTaxaController < ApplicationController
  before_filter :login_required

  def index
    redirect_to lists_path
  end
  
  def show
    @listed_taxon = ListedTaxon.find_by_id(params[:id])
    redirect_to list_path(@listed_taxon.list)
  end
  
  def create
    @list = List.find_by_id(params[:listed_taxon][:list_id])
    
    unless @list && @list.editable_by?(current_user)
      flash[:notice] = "Sorry, you don't have permission to add to this list."
      redirect_to lists_path
    end
    
    @taxon = Taxon.find_by_id(params[:listed_taxon][:taxon_id])
    @listed_taxon = @list.add_taxon(@taxon)
    
    respond_to do |format|
      format.html do
        if @listed_taxon.valid?
          flash[:notice] = "List udpated!"
        else
          flash[:error] = "D'oh, there was a problem updating your list: " +
                          @listed_taxon.errors.full_messages.join(', ')
        end
        return redirect_to lists_path if @listed_taxon.list_id.nil?
        redirect_to list_path(@listed_taxon.list)
      end
      format.json do
        partial = 'lists/' + (params[:partial] || 'listed_taxon') + ".html.erb"
        if @listed_taxon.valid?
          render(:json => {
            :instance => @listed_taxon,
            :extra => {
              :taxon => @listed_taxon.taxon,
              :iconic_taxon => @listed_taxon.taxon.iconic_taxon
            },
            :html => render_to_string(
              :partial => partial, 
              :locals => {:listed_taxon => @listed_taxon, :seenit => true}
            )
          })
        else
          render(
            :json => {
              :object => @listed_taxon,
              :errors => @listed_taxon.errors
            },
            :status => :unprocessable_entity
          )
        end
      end
    end
  end

  def destroy
    @listed_taxon = ListedTaxon.find_by_id(params[:id], :include => :list)
    
    unless @listed_taxon && @listed_taxon.list.editable_by?(current_user)
      flash[:notice] = "Sorry, you don't have permission to delete from " + 
        "this list."
      return redirect_to lists_path
    end
    
    @listed_taxon.destroy
    
    respond_to do |format|
      format.html do
        flash[:notice] = "Taxon removed from list."
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
end
