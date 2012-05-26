class SubscriptionsController < ApplicationController
  before_filter :login_required
  before_filter :load_subscription, :except => [:new, :create, :index, :edit]
  before_filter :require_owner, :except => [:new, :create, :index, :edit]
  
  def index
    @subscriptions = current_user.subscriptions.paginate(
      :page => params[:page], 
      :include => :resource,
      :order => "subscriptions.id desc")
  end

  def edit
    @subscription = Subscription.find_by_id(params[:id]) if params[:id]
    if params[:resource_type] && params[:resource_id]
      @resource = Object.const_get(params[:resource_type]).find_by_id(params[:resource_id]) rescue nil
      if @resource
        @subscription ||= current_user.subscriptions.first(:conditions => {
          :resource_type => params[:resource_type], 
          :resource_id => params[:resource_id]})
      end
    end
    @resource ||= @subscription.resource if @subscription
    
    if @subscription && @subscription.user_id != current_user.id
      flash[:error] = "You don't have permission to do that"
      return redirect_back_or_default(@subscription.resource)
    end
    
    if (partial = params[:partial]) && partial == 'edit_inline'
      render :partial => partial, :layout => false
      return
    end
  end

  def create
    @subscription = Subscription.new(params[:subscription])
    @subscription.user = current_user
    respond_to do |format|
      if @subscription.save
        format.html do
          flash[:notice] = "Subscription saved."
          return redirect_back_or_default(@subscription.resource)
        end
        format.json { render :json => @subscription }
      else
        msg = "Failed to create subscription: #{@subscription.errors.full_messages.to_sentence}"
        format.html do
          flash[:error] = msg
          return redirect_back_or_default(@subscription.resource)
        end
        format.json do
          render :status => :unprocessable_entity, :json => {:error => msg}
        end
      end
    end
  end
  
  def update
    respond_to do |format|
      if @subscription.update_attributes(params[:subscription])
        format.html do
          flash[:notice] = "Subscription updated."
          return redirect_back_or_default(@subscription.resource)
        end
      else
        format.html { render :action => :edit }
      end
    end
  end

  def destroy
    @subscription.destroy
    respond_to do |format|
      format.html do
        flash[:notice] = "Subscription deleted."
        return redirect_back_or_default(@subscription.resource)
      end
      format.json do
        render :status => :ok, :json => {}
      end
    end
  end
  
  private
  def load_subscription
    @subscription = if params[:id]
      Subscription.find_by_id(params[:id])
    elsif params[:resource_type] && params[:resource_id]
      current_user.subscriptions.first(:conditions => {
        :resource_type => params[:resource_type], 
        :resource_id => params[:resource_id]})
    end
    render_404 unless @subscription
  end
  
  def require_owner
    unless logged_in? && current_user.id == @subscription.user_id
      flash[:error] = "You don't have permission to do that"
      return redirect_back_or_default(@subscription.resource)
    end
  end
end
