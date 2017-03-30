class CommentsController < ApplicationController
  before_action :doorkeeper_authorize!,
    only: [ :create, :update, :destroy ],
    if: lambda { authenticate_with_oauth? }
  before_filter :authenticate_user!, :except => [:index], :unless => lambda { authenticated_with_oauth? }
  before_filter :admin_required, :only => [:user]
  before_filter :load_comment, :only => [:show, :edit, :update, :destroy]
  before_filter :owner_required, :only => [:edit, :update]
  
  def index
    find_options = {
      :select => "MAX(comments.id) AS id, parent_id",
      :page => params[:page],
      :order => "id DESC",
      :group => "parent_id"
    }
    @paging_comments = Comment.all
    if logged_in? && (!params[:mine].blank? || !params[:for_me].blank? || !params[:q].blank?)
      filtering = true
      if !params[:mine].blank?
        @paging_comments = @paging_comments.by(current_user)
      elsif !params[:for_me].blank?
        @paging_comments = @paging_comments.for_observer(current_user)
      end
      @paging_comments = @paging_comments.dbsearch(params[:q]) unless params[:q].blank?
    end
    if !filtering && @site && @site.site_only_users
      @paging_comments = @paging_comments.joins(:user).where("users.site_id = ?", @site)
    end
    @paging_comments = @paging_comments.select(find_options[:select]).
      group(find_options[:group]).paginate(page: find_options[:page]).
      order(find_options[:order])
    @comments = Comment.where("comments.id IN (?)", @paging_comments.map{|c| c.id}).includes(:user).order("comments.id desc")
    @extra_comments = Comment.where(parent_id: @comments.map(&:parent_id))
    @extra_ids = Identification.where(observation_id: @comments.map(&:parent_id)).includes(:observation)
    @extra_comments_and_ids = [@extra_comments,@extra_ids].flatten
    @comments_by_parent_id = @extra_comments_and_ids.sort_by{|c| c.created_at}.group_by{|c| (c.respond_to? :observation_id) ? [c.observation.class.to_s,c.observation_id].join("_") : [c.parent.class.to_s,c.parent_id].join("_") }
    respond_to do |format|
      format.html do
        if params[:partial]
          render :partial => 'listing_for_dashboard', :collection => @comments, :layout => false
        end
      end
    end
  end
  
  def user
    @display_user = User.find_by_id(params[:id]) || User.find_by_login(params[:login])
    return render_404 unless @display_user
    @comments = @display_user.comments.order(id: :desc).page(params[:page])
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
          Observation.refresh_es_index
          render :json => @comment.to_json(:methods => [:html])
        else
          render :status => :unprocessable_entity, :json => {:errors => @comment.errors.full_messages}
        end
      end
    end
  end
  
  def update
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
        Observation.refresh_es_index
        @comment.html = view_context.render_in_format(:html, :partial => 'comments/comment')
        render :json => @comment.to_json(:methods => [:html])
      end
    end
  end
  
  def destroy
    unless @comment.deletable_by?(current_user)
      msg = t(:you_dont_have_permission_to_do_that)
      respond_to do |format|
        format.html do
          flash[:error] = msg
          redirect_to @comment
        end
        format.json do
          render :json => {:error => msg}
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
        Observation.refresh_es_index
        head :ok
      end
    end
  end
  
  private
  def redirect_to_parent
    anchor = "activity_comment_#{@comment.id}"
    if @comment.parent.is_a?( Post )
      post = @comment.parent
      redirect_to( post_path( post, anchor: anchor ) )
    elsif @comment.parent.is_a?( TaxonLink )
      redirect_to( edit_taxon_link_path( @comment.parent, anchor: anchor ) )
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

  def load_comment
    render_404 unless @comment = Comment.find_by_id(params[:id] || params[:comment_id])
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
          render :json => {:error => msg}
        end
      end
      return 
    end
  end
end
