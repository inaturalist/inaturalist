class CommentsController < ApplicationController
  before_action :doorkeeper_authorize!,
    only: [ :create, :update, :destroy ],
    if: lambda { authenticate_with_oauth? }
  before_action :authenticate_user!, :unless => lambda { authenticated_with_oauth? }
  before_action :load_record, :only => [:show, :edit, :update, :destroy, :hide]
  before_action :owner_required, :only => [:edit, :update]
  before_action :curator_required, only: [:user]
  check_spam only: [:create, :update], instance: :comment
  
  def index
    @comments = Comment.includes(:user).order( "comments.id DESC" ).page( params[:page] )
    if logged_in? && (!params[:mine].blank? || !params[:for_me].blank? || !params[:q].blank?)
      filtering = true
      if !params[:mine].blank?
        @comments = @comments.by(current_user)
      elsif !params[:for_me].blank?
        @comments = @comments.for_observer(current_user)
      end
      @comments = @comments.dbsearch(params[:q]) unless params[:q].blank?
    end
    if !filtering && @site && @site.site_only_users
      @comments = @comments.joins(:user).where("users.site_id = ?", @site)
    end
    parent_ids = @comments.map(&:parent_id)
    @extra_comments = Comment.where( parent_id: parent_ids ).
      where( "comments.id NOT IN (?)", @comments.map(&:id) ).includes(:user)
    @extra_ids = Identification.where( observation_id: parent_ids ).includes(:observation)
    comments_and_ids = [@comments, @extra_comments, @extra_ids].flatten.uniq
    @comments_by_parent_id = comments_and_ids.sort_by(&:created_at).group_by do |c|
      if c.respond_to? :observation_id
        [c.observation.class.to_s, c.observation_id].join( "_" )
      else
        [c.parent.class.to_s, c.parent_id].join( "_" )
      end
    end
    @latest_comments = @comments_by_parent_id.map {|g,items|
      items.select {|i| i.is_a?( Comment ) }.compact.sort_by(&:created_at).last
    }.compact.sort_by(&:created_at).reverse
    respond_to do |format|
      format.html do
        if params[:partial]
          render partial: "listing_for_dashboard",
            collection: @latest_comments, layout: false
        end
      end
    end
  end

  def user
    @display_user = User.find_by_id( params[:id] ) || User.find_by_login( params[:login] )
    return render_404 unless @display_user

    @comments = @display_user.comments.order( id: :desc ).page( params[:page] )
  end

  def show
    redirect_to_parent
  end
  
  def new
    @comment = Comment.new
  end
  
  def edit
    respond_to do |format|
      format.html
    end
  end
  
  def create
    @comment = Comment.new(params[:comment])
    @comment.user = current_user
    @comment.save unless params[:preview]
    respond_to do |format|
      format.html { respond_to_create }
      format.json do
        if @comment.valid?
          if params[:partial] == "activity_item"
            @comment.html = view_context.render_in_format(:html, :partial => 'shared/activity_item', :object => @comment)
          else
            @comment.html = view_context.render_in_format(:html, :partial => 'comments/comment')
          end
          render :json => @comment.to_json(:methods => [:html])
        else
          render :status => :unprocessable_entity, :json => {:errors => @comment.errors.full_messages}
        end
      end
    end
  end
  
  def update
    if @comment.hidden?
      respond_to do |format|
        msg = t(:cant_edit_or_delete_hidden_content)
        format.html do
          flash[:error] = msg
          redirect_to_parent
        end
        format.json do
          render json: { error: msg }
        end
      end
      return
    end
    @comment.attributes = params[:comment]
    @comment.save unless params[:preview]
    respond_to do |format|
      format.html do
        if @comment.valid?
          flash[:notice] = t(:your_comment_was_saved)
        else
          flash[:error] = t(:we_had_trouble_saving_comment) +
            @comment.errors.full_messages.join(', ')
        end
        redirect_to_parent
      end
      format.json do
        @comment.html = view_context.render_in_format(:html, :partial => 'comments/comment')
        render :json => @comment.to_json(:methods => [:html])
      end
    end
  end
  
  def destroy
    if @comment.hidden?
      respond_to do |format|
        msg = t(:cant_edit_or_delete_hidden_content)
        format.html do
          flash[:error] = msg
          redirect_to_parent
        end
        format.json do
          render json: { error: msg }
        end
      end
      return
    end
    
    unless @comment.deletable_by?(current_user)
      msg = t(:you_dont_have_permission_to_do_that)
      respond_to do |format|
        format.html do
          flash[:error] = msg
          redirect_to @comment
        end
        format.json do
          render :json => {:error => msg}, status: :forbidden
        end
      end
      return
    end

    parent = @comment.parent
    @comment.destroy
    respond_to do |format|
      format.html do
        flash[:notice] = t(:comment_deleted)
        redirect_back_or_default(parent)
      end
      format.any(:js, :json) do
        head :ok
      end
    end
  end

  def hide
    @item = @comment
    render "moderator_actions/hide_content"
  end

  private
  def redirect_to_parent
    anchor = "activity_comment_#{@comment.uuid}"
    if @comment.parent.is_a?( Trip )
      trip = @comment.parent
      redirect_to( trip_path( trip, anchor: anchor ) )
    elsif @comment.parent.is_a?( Post )
      post = @comment.parent
      redirect_to( post_path( post, anchor: anchor ) )
    elsif @comment.parent.is_a?( TaxonLink )
      redirect_to( edit_taxon_link_path( @comment.parent, anchor: anchor ) )
    elsif @comment.parent.is_a?( Observation )
      anchor = "activity_comment_#{@comment.uuid}"
      redirect_to( url_for( @comment.parent ) + "##{anchor}" )
    else
      redirect_to( url_for( @comment.parent ) + "##{anchor}" )
    end
  end
  
  def respond_to_create
    if @comment.valid?
      flash[:notice] = t(:your_comment_was_saved)
      return redirect_to(params[:return_to]) unless params[:return_to].blank?
    else
      flash[:error] = "#{t(:we_had_trouble_saving_comment)} #{@comment.errors.full_messages.join(', ')}"
    end
    redirect_to_parent
  end
  
  def owner_required
    unless logged_in? && (current_user.is_admin? || current_user.id == @comment.user_id)
      msg = t(:you_dont_have_permission_to_do_that)
      respond_to do |format|
        format.html do
          flash[:error] = msg
          redirect_to @comment
        end
        format.json do
          render :json => {:error => msg}, status: :forbidden
        end
      end
      return 
    end
  end
end
