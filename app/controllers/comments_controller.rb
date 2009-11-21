class CommentsController < ApplicationController
  before_filter :login_required, :except => :index
  cache_sweeper :comment_sweeper, :only => [:create, :destroy]
  
  def index
    find_options = {
      :page => params[:page], :order => "id DESC",
      :include => :user,
      :group => "parent_id"
    }
    @comments = Comment.scoped({})
    @comments = @comments.by(current_user) if logged_in? && params[:mine]
    @comments = @comments.paginate(find_options)
    @extra_comments = Comment.all(:conditions => [
      "parent_id IN (?) AND created_at >= ?", 
      @comments.map(&:parent_id), @comments.last.created_at
    ]).sort_by(&:id)
    @comments_by_parent_id = @extra_comments.group_by(&:parent_id)
  end
  
  def show
    @comment = Comment.find(params[:id])
    redirect_to_parent
  end
  
  def new
    @comment = Comment.new
  end
  
  def edit
    @comment = Comment.find(params[:id])
  end
  
  def create
    @comment = Comment.new(params[:comment])
    @comment.save unless params[:preview]
    respond_to do |format|
      format.html do
        if @comment.valid?
          flash[:notice] = "Your comment was saved."
          if params[:return_to]
            return redirect_to(params[:return_to])
          end
        else
          flash[:error] = "We had trouble saving your comment: " +
            @comment.errors.full_messages.join(', ')
        end
        redirect_to_parent
      end
      format.js
    end
  end
  
  def update
    @comment = Comment.find(params[:id])
    @comment.attributes = params[:comment]
    @comment.save unless params[:preview]
    respond_to do |format|
      format.html do
        if @comment.valid?
          flash[:notice] = "Your comment was saved."
        else
          flash[:error] = "We had trouble saving your comment: " +
            @comment.errors.full_messages.join(', ')
        end
        redirect_to_parent
      end
      format.js
    end
  end
  
  def destroy
    @comment = Comment.find(params[:id])
    parent = @comment.parent
    @comment.destroy
    respond_to do |format|
      format.html { redirect_to_parent }
    end
  end
  
  private
  def redirect_to_parent
    if @comment.parent.is_a?(Post)
      redirect_to post_path(@comment.parent.user.login, @comment.parent)
    else
      redirect_to(url_for(@comment.parent) + "#comment-#{@comment.id}")
    end
  end
end
