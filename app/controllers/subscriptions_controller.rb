class SubscriptionsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_subscription, :except => [:new, :create, :index, :edit, :subscribe]
  before_filter :load_resource, only: [:subscribe]
  before_filter :require_owner, :except => [:new, :create, :index, :edit, :subscribe]
  before_filter :return_here, :only => [:index]
  
  def index
    @type = params[:type]
    @type = "place" unless Subscription.subscribable_classes.map(&:underscore).include?(@type)
    resource_type = @type.camelcase
    @subscriptions = current_user.subscriptions.includes(:resource).
      where("resource_type = ?", resource_type).
      order("subscriptions.id desc").
      page(params[:page])
  end

  def new
    @type = params[:type]
    @type = "place" unless Subscription.subscribable_classes.map(&:underscore).include?(@type)
    resource_type = @type.camelcase
    @resource = Object.const_get(resource_type).find_by_id(params[:resource_id]) rescue nil
    @subscription = Subscription.new(:user => current_user, :resource_type => resource_type, :resource => @resource)
    if params[:partial] && params[:partial] == "form"
      render :partial => params[:partial], :layout => false
    end
  end

  def edit
    @subscription = Subscription.find_by_id(params[:id]) if params[:id]
    if params[:resource_type] && params[:resource_id]
      @resource = Object.const_get(params[:resource_type]).find_by_id(params[:resource_id]) rescue nil
      if @resource
        @subscription ||= current_user.subscriptions.where(
          resource_type: params[:resource_type], resource_id: params[:resource_id]).first
      end
    end
    return render_404 unless @subscription
    @resource ||= @subscription.resource
    @type = @resource.class.to_s if @resource
    
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
          return redirect_back_or_default(@subscription.resource || '/')
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
        format.json { render json: @subscription }
      else
        format.html { render :action => :edit }
        format.json do
          render :status => :unprocessable_entity, json: { error: @subscription.errors.full_messages.to_sentence }
        end
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

  def subscribe
    @subscription = current_user.subscriptions.where(resource: @resource).first
    if !@subscription && (params[:subscribe].nil? || params[:subscribe].yesish?)
      @subscription = Subscription.create(resource: @resource, user: current_user)
    elsif @subscription
      @subscription.destroy
    end
    respond_to do |format|
      format.html { redirect_to @resource }
      format.json { head :no_content }
    end
  end
  
  private
  def load_subscription
    @subscription = if params[:id]
      Subscription.find_by_id(params[:id])
    elsif params[:resource_type] && params[:resource_id]
      current_user.subscriptions.where(
        resource_type: params[:resource_type], resource_id: params[:resource_id]).first
    end
    render_404 unless @subscription
  end

  def load_resource
    subscribable_classes = Subscription.subscribable_classes
    resource_type = if subscribable_classes.include?( params[:resource_type] )
      params[:resource_type]
    end
    return render_404 unless resource_type
    klass = Object.const_get( resource_type )
    if klass.column_names.include?( "uuid" )
      @resource ||= klass.find_by_uuid( params[:resource_id] ) rescue nil
    end
    @resource ||= klass.find_by_id( params[:resource_id] ) rescue nil
    render_404 unless @resource
  end
  
  def require_owner
    unless logged_in? && current_user.id == @subscription.user_id
      flash[:error] = "You don't have permission to do that"
      return redirect_back_or_default(@subscription.resource)
    end
  end
end
