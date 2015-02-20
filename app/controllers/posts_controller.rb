class PostsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show, :browse]
  load_only = [ :show, :edit, :update, :destroy ]
  before_filter :load_post, :only => load_only
  blocks_spam :only => load_only, :instance => :post
  before_filter :load_parent, :except => [:browse, :create, :update, :destroy]
  before_filter :load_new_post, :only => [:new, :create]
  before_filter :author_required, :only => [:edit, :update, :destroy]

  layout "bootstrap"
  
  def index
    scope = @parent.is_a?(User) ? @parent.journal_posts.scoped : @parent.posts.scoped
    if @parent.is_a?(User)
      block_if_spammer(@parent) && return
    else
      block_if_spam(@parent) && return
    end
    @posts = scope.not_flagged_as_spam.published.page(params[:page]).
      per_page(10).order("published_at DESC")
    
    # Grab the monthly counts of all posts to show archives
    get_archives
    
    if logged_in? && (current_user == @display_user || (@parent.is_a?(Project) && @parent.editable_by?(current_user)))
      @drafts = scope.unpublished.order("created_at DESC")
    end
    
    respond_to do |format|
      format.html
      format.atom
    end
  end
  
  def show
    if params[:login].blank? && params[:project_id].blank?
      if @post.parent_type == "User"
        redirect_to journal_post_path(@parent.login, @post)
      else
        redirect_to project_journal_post_path(@parent, @post)
      end
      return
    end

    if params[:login] && @parent.is_a?(Project)
      redirect_to project_journal_post_path(@parent, @post)
      return
    end

    if params[:project_id] && @parent.is_a?(User)
      redirect_to journal_post_path(@parent.login, @post)
      return
    end
    
    unless @post.published_at
      if logged_in? && @post.user_id == current_user.id
        flash[:notice] ||= "Preview"
      else
        render_404 and return
      end
    end
    
    respond_to do |format|
      format.html do
        @next = @post.parent.journal_posts.published.where("published_at > ?", @post.published_at || @post.updated_at).order("published_at ASC").first
        @prev = @post.parent.journal_posts.published.where("published_at < ?", @post.published_at || @post.updated_at).order("published_at DESC").first
        @trip = @post
        @observations = @post.observations.order_by('observed_on')
        @shareable_image_url = @post.body[/img.+src="(.+?)"/, 1] if @post.body
        @shareable_image_url ||= if @post.parent_type == "Project"
          FakeView.image_url(@post.parent.icon.url(:original))
        else
          FakeView.image_url(@post.user.icon.url(:original))
        end
        @shareable_description = FakeView.truncate(@post.body, :length => 1000) if @post.body
        render "trips/show"
      end
    end
  end
  
  def new
    if @list = List.find_by_id(params[:list_id])
      @listed_taxa = @list.listed_taxa.includes(:taxon).limit(500)
      @listed_taxa.each do |lt|
        @post.trip_taxa.build(:taxon => lt.taxon)
      end
    end
  end
  
  def create
    @post.parent ||= current_user
    @display_user = current_user
    @post.published_at = Time.now if params[:commit] == t(:publish)
    if params[:observations]
      @post.observations << Observation.by(current_user).find(params[:observations])
    end
    if @post.save
      if @post.published_at
        flash[:notice] = t(:post_published)
        # redirect_to (@post.parent.is_a?(Project) ?
        #              project_journal_post_path(@post.parent.slug, @post) :
        #              journal_post_path(@post.user.login, @post))
        redirect_to path_for_post(@post)
      else
        flash[:notice] = t(:draft_saved)
        # redirect_to (@post.parent.is_a?(Project) ?
        #              edit_project_journal_post_path(@post.parent.slug, @post) :
        #              edit_journal_post_path(@post.user.login, @post))
        redirect_to edit_path_for_post(@post)
      end
    else
      render :action => :new
    end
  end
    
  def edit
    @preview = params[:preview]
  end
  
  def update
    @post.published_at = Time.now if params[:commit] == t(:publish)
    @post.published_at = nil if params[:commit] == t(:unpublish)
    if params[:observations]
      params[:observations] = params[:observations].map(&:to_i)
      params[:observations] = ((params[:observations] & @post.observation_ids) + params[:observations]).uniq
      @observations = Observation.by(current_user).all(
        :conditions => ["id IN (?)", params[:observations]])
    end
    if params[:commit] == t(:preview)
      @post.attributes = params[:post]
      @preview = @post
      @observations ||= @post.observations.all(:include => [:taxon, :photos])
      return render(:action => 'edit')
    end
    
    # This will actually perform the updates / deletions, so it needs to 
    # happen after preview rendering
    if @observations
      @post.observations = @observations
    else
      @post.observations.clear
    end

    if @post.update_attributes(params[@post.class.name.underscore.to_sym])
      if @post.published_at
        flash[:notice] = t(:post_published)
        redirect_to (@post.parent.is_a?(Project) ?
                     project_journal_post_path(@post.parent.slug, @post) :
                     journal_post_path(@post.user.login, @post))
      else
        flash[:notice] = t(:draft_saved)
        redirect_to (@post.parent.is_a?(Project) ?
                     edit_project_journal_post_path(@post.parent.slug, @post) :
                     edit_journal_post_path(@post.user.login, @post))
      end
    else
      render :action => :edit
    end
  end
  
  def destroy
    @post.destroy
    flash[:notice] = t(:journal_post_deleted)
    redirect_to (@post.parent.is_a?(Project) ?
                 project_journal_path(@post.parent.slug) :
                 journal_by_login_path(@post.user.login))
  end
  
  def archives    
    @target_date = Date.parse("#{params[:year]}-#{params[:month]}-01")
    @posts = @parent.posts.paginate(
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
    @posts = Post.published.page(params[:page] || 1).order('published_at DESC')
    respond_to do |format|
      format.html
    end
  end
  
  private
  
  def get_archives(options = {})
    scope = @parent.is_a?(User) ? @parent.journal_posts.scoped : @parent.posts.scoped
    @archives = scope.published.count(
      :group => "TO_CHAR(published_at, 'YYYY MM Month')")
    @archives = @archives.to_a.sort_by(&:first).reverse.map do |month_str, count|
      [month_str.split, count].flatten
    end

  end
  
  def load_parent
    if params[:login]
      @display_user = User.find_by_login(params[:login])
      @parent = @display_user
    elsif params[:project_id]
      @display_project = Project.find(params[:project_id])
      @parent = @display_project
    end
    if @post
      @display_user ||= @post.user if @post
      @parent ||= @post.parent if @post
    elsif logged_in? && current_user.login == params[:login]
      @display_user ||= current_user
      @parent ||= current_user
    end
    return render_404 if @parent.blank?
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

  def load_new_post
    @post = Post.new(params[:post])
    @post.parent ||= @parent
    @post.user ||= current_user
    true
  end
  
  def load_post
    @post = Post.find_by_id(params[:id])
    if request.fullpath =~ /\/trips/
      @post.becomes(Trip)
    end
    render_404 and return unless @post
    true
  end
  
  def author_required
    if ((@post.parent.is_a?(Project) && !@post.parent.editable_by?(current_user)) ||
        !(logged_in? && @post.user.id == current_user.id))
      flash[:notice] = t(:only_the_author_of_this_post_can_do_that)
      redirect_to (@post.parent.is_a?(Project) ?
                   project_journal_path(@post.parent.slug) :
                   journal_by_login_path(@post.user.login))
    end
  end

  def path_for_post(post)
    if post.parent.is_a? Project
      project_journal_post_path(post.parent.slug, post)
    elsif post.is_a? Trip
      trip_path(post)
    else
      journal_post_path(post.user.login, post)
    end
  end

  def edit_path_for_post(post)
    if post.parent.is_a? Project
      edit_project_journal_post_path(post.parent.slug, post)
    elsif post.is_a? Trip
      edit_trip_path(post)
    else
      edit_journal_post_path(post.user.login, post)
    end
  end
end
