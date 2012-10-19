class PostsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show, :browse]
  before_filter :load_post, :only => [:show, :edit, :update, :destroy]
  #before_filter :load_display_user_by_login, :except => [:browse, :create, :new]
  before_filter :load_parent, :except => [:browse, :create]
  before_filter :author_required, :only => [:edit, :update, :destroy]
  
  def index
    @posts = @parent.posts.published.paginate(:page => params[:page] || 1, 
      :per_page => 10, :order => "published_at DESC")
    
    # Grab the monthly counts of all posts to show archives
    get_archives
    
    if logged_in? && @display_user == current_user
      @drafts = @display_user.posts.unpublished.all(
        :order => "created_at DESC")
    end
    
    respond_to do |format|
      format.html
      format.atom
    end
  end
  
  def show
    if (params[:login].blank? && params[:project_id].blank?)
      redirect_to journal_post_path(@display_user.login, @post)
      return
    end
    
    unless @post.published_at
      if logged_in? && @post.user_id == current_user.id
        flash[:notice] ||= "Preview"
      else
        render_404 and return
      end
    end
    @previous = @parent.posts.published.find(:first, 
      :conditions => ["published_at < ?", @post.published_at],
      :order => "published_at DESC")
    @next = @parent.posts.published.find(:first, 
      :conditions => ["published_at > ?", @post.published_at],
      :order => "published_at ASC")
    @observations = @post.observations.order_by('observed_on')
  end
  
  def new
    # if params include a project_id, parent is the project.  otherwise, parent is current_user.
    @post = Post.new(:parent => @parent, :user => current_user)
    @observations = @parent.observations.latest.all(
      :limit => 10, :include => [:taxon, :photos])
  end
  
  def create
    @post = Post.new(params[:post])
    @post.parent ||= current_user
    @display_user = current_user
    @post.published_at = Time.now if params[:commit] == 'Publish'
    if params[:observations]
      @post.observations << Observation.by(current_user).find(params[:observations])
    end
    if @post.save
      if @post.published_at
        flash[:notice] = "Post published!"
        #redirect_to (journal_post_path(@post.user.login, @post)
        redirect_to (@post.parent.is_a?(Project) ?
                     project_journal_post_path(@post.parent.slug, @post) :
                     journal_post_path(@post.user.login, @post))
      else
        flash[:notice] = "Draft saved!"
        redirect_to edit_post_path(@post)
      end
    else
      render :action => :new
    end
  end
    
  def edit
    @observations = @post.observations.all(:include => [:taxon, :photos])
  end
  
  def update
    @post.published_at = Time.now if params[:commit] == 'Publish'
    @post.published_at = nil if params[:commit] == 'Unpublish'
    if params[:observations]
      params[:observations] = params[:observations].map(&:to_i)
      params[:observations] = ((params[:observations] & @post.observation_ids) + params[:observations]).uniq
      @observations = Observation.by(current_user).all(
        :conditions => ["id IN (?)", params[:observations]])
    end
    if params[:commit] == 'Preview'
      @post.attributes = params[:post]
      @preview = @post
      @observations ||= @post.observations.all(:include => [:taxon, :photos])
      return render(:action => 'edit')
    end
    
    # This will actually perform the updates / deletions, so it needs to 
    # happen after preview rendering
    @post.observations = @observations if @observations
    
    if @post.update_attributes(params[:post])
      if @post.published_at
        flash[:notice] = "Post published!"
        redirect_to journal_post_path(@post.user.login, @post)
      else
        flash[:notice] = "Draft saved!"
        redirect_to edit_post_path(@post)
      end
    else
      render :action => :edit
    end
  end
  
  def destroy
    @post.destroy
    flash[:notice] = "Journal post deleted."
    redirect_to journal_by_login_path(@post.user.login)
  end
  
  def archives    
    @target_date = Date.parse("#{params[:year]}-#{params[:month]}-01")
    @posts = @display_user.posts.paginate(
      :page => params[:page] || 1,
      :per_page => 10,
      :conditions => [
        "published_at >= ? AND published_at < ?", 
        @target_date, 
        @target_date + 1.month
      ]
    )
    
    get_archives
  end
  
  def browse
    @posts = Post.published.paginate(:page => params[:page] || 1, 
      :order => 'published_at DESC')
  end
  
  private
  
  def get_archives
    @archives = @parent.posts.published.count(
      :group => "TO_CHAR(published_at, 'YYYY MM Month')")
    @archives = @archives.to_a.sort_by(&:first).reverse.map do |month_str, count|
      [month_str.split, count].flatten
    end

  end
  
  def load_parent
    if params[:login]
      @display_user = User.find_by_login(params[:login])
      @display_user ||= @post.user if @post
    elsif params[:project_id]
      @display_project = Project.find(params[:project_id])
    end
    @parent = (@display_user || @display_project)
    render_404 and return if @parent.nil?
    if @parent.is_a?(Project)
      @parent_display_name = @parent.title 
      @parent_slug = @parent.slug
    else
      @parent_display_name = @parent.login
      @selected_user = @display_user
      @parent_slug = @login = @selected_user.login
    end
    true
  end
  
  def load_post
    @post = Post.find_by_id(params[:id])
    render_404 and return unless @post
    true
  end
  
  def author_required
    unless logged_in? && @post.user.id == current_user.id
      flash[:notice] = "Only the author of this post can do that.  " + 
                       "Don't be evil."
      redirect_to journal_by_login_path(@display_user.login)
    end
  end
end
