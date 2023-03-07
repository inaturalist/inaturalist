# frozen_string_literal: true

class PostsController < ApplicationController
  before_action :doorkeeper_authorize!, only: %i[for_project_user for_user], if: -> { authenticate_with_oauth? }
  before_action :authenticate_user!, except: %i[index show browse for_user archives search],
                unless: -> { authenticated_with_oauth? }
  load_only = %i[show edit update destroy]
  before_action :load_post, only: load_only
  blocks_spam only: load_only, instance: :post
  check_spam only: %i[create update], instance: :post
  before_action :load_parent, except: %i[browse for_project_user for_user]
  before_action :load_new_post, only: %i[new create]
  before_action :owner_required, only: %i[create edit update destroy]

  # Might want to try this if /journal becomes a problem.
  # caches_action :browse,
  #   expires_in: 15.minutes,
  #   cache_path: Proc.new {|c|
  #     c.send( journals_url, locale: I18n.locale, from: c.params[:from] )
  #   },
  #   if: Proc.new {|c|
  #     (c.params.keys - %w(action controller format)).blank?
  #   }

  layout "bootstrap"

  def index
    scope = @parent.is_a?( User ) ? @parent.journal_posts : @parent.posts
    return if @parent.is_a?( User ) && block_if_spammer( @parent )

    return if !@parent.is_a?( Site ) && block_if_spam( @parent )

    per_page = params[:per_page].to_i
    per_page = 10 if per_page <= 0
    per_page = 200 if per_page > 200
    @posts = scope.not_flagged_as_spam.published.page( params[:page] ).
      per_page( per_page ).order( "published_at DESC" )

    if !params[:newer_than].blank? && ( newer_than_post = Post.find_by_id( params[:newer_than] ) )
      @posts = @posts.where( "posts.published_at > ?", newer_than_post.published_at )
    end
    if !params[:older_than].blank? && ( older_than_post = Post.find_by_id( params[:older_than] ) )
      @posts = @posts.where( "posts.published_at < ?", older_than_post.published_at )
    end

    # Grab the monthly counts of all posts to show archives
    get_archives

    if @parent == current_user || ( @parent.respond_to?( :editable_by? ) && @parent.editable_by?( current_user ) )
      @drafts = scope.unpublished.order( "created_at DESC" )
    end

    pagination_headers_for( @posts )

    # TODO: Rails 5 - pleary 06/30/21: I removed :site_name_short from methods as Rails 5 throws
    # an error for missing methods. We should only use methods shared by all post parent classes
    respond_to do | format |
      format.html
      format.atom
      format.json do
        render json: @posts, include: {
          user: {
            only: [:id, :login],
            methods: [:user_icon_url, :medium_user_icon_url]
          },
          parent: {
            only: [:id, :title, :name],
            methods: [:icon_url]
          }
        }
      end
    end
  end

  def show
    case @post.parent_type
    when "User" && params[:login].blank?
      redirect_to journal_post_path( @parent.login, @post )
      return
    when "Project" && params[:project_id].blank?
      redirect_to project_journal_post_path( @parent, @post )
      return
    when "Site" && ( params[:project_id] || params[:login] )
      redirect_to site_post_path( @post )
      return
    end

    if params[:login] && @parent.is_a?( Project )
      redirect_to project_journal_post_path( @parent, @post )
      return
    end

    if params[:project_id] && @parent.is_a?( User )
      redirect_to journal_post_path( @parent.login, @post )
      return
    end

    unless @post.published_at
      return render_404 if !logged_in? || @post.user_id != current_user.id

      flash[:notice] ||= "Preview"
    end

    respond_to do | format |
      format.html do
        @next = @post.parent.journal_posts.published.where( "published_at > ?",
          @post.published_at || @post.updated_at ).order( "published_at ASC" ).first
        @prev = @post.parent.journal_posts.published.where( "published_at < ?",
          @post.published_at || @post.updated_at ).order( "published_at DESC" ).first
        @trip = @post
        user_viewed_updates_for( @trip ) if logged_in?
        @observations = @post.observations.order_by( "observed_on" )
        @shareable_image_url = @post.body[/img.+?src=["'](.+?)["']/, 1] if @post.body
        @shareable_image_url ||= case @post.parent_type
        when "Project"
          helpers.image_url( @post.parent.icon.url( :original ) )
        when "User"
          helpers.image_url( @post.user.icon.url( :original ) )
        when "Site"
          helpers.image_url( @post.parent.logo_square.url )
        end
        @shareable_description = helpers.shareable_description( @post.body ) if @post.body
        render "trips/show"
      end
      format.json { render json: @post }
    end
  end

  def new
    return unless ( @list = List.find_by_id( params[:list_id] ) )

    @listed_taxa = @list.listed_taxa.includes( :taxon ).limit( 500 )
    @listed_taxa.each do | lt |
      @post.trip_taxa.build( taxon: lt.taxon )
    end
  end

  def create
    @post.parent ||= current_user
    @display_user = current_user
    @post.published_at = Time.now if params[:commit] == t( :publish )
    if params[:observations]
      @post.observations << Observation.by( current_user ).find( params[:observations] )
    end
    if @post.save
      respond_to do | format |
        format.html do
          if @post.published_at
            flash[:notice] = t( :post_published )
            redirect_to path_for_post( @post )
          else
            flash[:notice] = t( :draft_saved )
            redirect_to edit_path_for_post( @post )
          end
        end
        format.json do
          render json: @post
        end
      end
    else
      respond_to do | format |
        format.html { render action: :new }
        format.json { render status: :unprocessable_entity, json: { errors: @post.errors } }
      end
    end
  end

  def edit
    @preview = params[:preview]
  end

  def update
    @post.published_at = Time.now if params[:commit] == t( :publish )
    @post.published_at = nil if params[:commit] == t( :unpublish )
    if params[:observations]
      params[:observations] = params[:observations].map( &:to_i )
      params[:observations] = ( ( params[:observations] & @post.observation_ids ) + params[:observations] ).uniq
      @observations = Observation.by( current_user ).where( id: params[:observations] )
    end
    if params[:commit] == t( :preview )
      @post.attributes = params[:post]
      @preview = @post
      @observations ||= @post.observations.includes( :taxon, :photos )
      return render( action: "edit" )
    end

    # This will actually perform the updates / deletions, so it needs to
    # happen after preview rendering
    if @observations
      @post.observations = @observations
    else
      @post.observations.clear
    end

    if @post.update( params[@post.class.name.underscore.to_sym] )
      respond_to do | format |
        format.html do
          if @post.published_at
            flash[:notice] = t( :post_published )
            redirect_to path_for_post( @post )
          else
            flash[:notice] = t( :draft_saved )
            redirect_to edit_path_for_post( @post )
          end
        end
        format.json do
          render json: @post
        end
      end
    else
      respond_to do | format |
        format.html { render action: :edit }
        format.json { render status: :unprocessable_entity, json: { errors: @post.errors } }
      end
    end
  end

  def destroy
    @post.destroy
    respond_to do | format |
      format.html do
        flash[:notice] = t( :journal_post_deleted )
        redirect_to parent_path_for_post( @post )
      end
      format.json { head :no_content }
    end
  end

  def archives
    @target_date = Date.parse( "#{params[:year]}-#{params[:month]}-01" )
    @posts = @parent.posts.
      where( ["published_at >= ? AND published_at < ?", @target_date, @target_date + 1.month] ).
      paginate( page: params[:page] || 1, per_page: 10 )
    get_archives
  end

  def search
    @posts = Post.not_flagged_as_spam.
      published.dbsearch( parent: @parent, q: params[:q] ).
      page( params[:page] ).per_page( limited_per_page )
    pagination_headers_for @posts
    respond_to do | format |
      format.html
      format.json { render json: @posts }
    end
  end

  def browse
    @posts = Post.not_flagged_as_spam.published.page( params[:page] || 1 ).order( "published_at DESC" )
    @posts = @posts.where( "posts.id < ?", params[:from] ) unless params[:from].blank?
    respond_to do | format |
      format.html
    end
  end

  def for_project_user
    for_user
  end

  def for_user
    site_id = current_user.site_id if logged_in?
    site_id ||= @site.id
    from_sql = "posts"
    where_sql = "(posts.parent_type = 'Site' AND posts.parent_id = #{site_id})"
    if logged_in?
      from_sql += " LEFT OUTER JOIN project_users pu ON pu.user_id = #{current_user.id}"
      where_sql += " OR (pu.project_id = posts.parent_id AND posts.parent_type = 'Project')"
    end
    posts_sql = <<-SQL
      SELECT DISTINCT ON (posts.id) posts.*
      FROM #{from_sql}
      WHERE #{where_sql}
    SQL
    @posts = Post.not_flagged_as_spam.published.
      from( "(#{posts_sql}) AS posts" ).
      order( "published_at DESC" ).
      page( params[:page] || 1 ).
      per_page( 30 )
    if !params[:newer_than].blank? && ( newer_than_post = Post.find_by_id( params[:newer_than] ) )
      @posts = @posts.where( "posts.published_at > ?", newer_than_post.published_at )
    end
    if !params[:older_than].blank? && ( older_than_post = Post.find_by_id( params[:older_than] ) )
      @posts = @posts.where( "posts.published_at < ?", older_than_post.published_at )
    end
    Post.preload_associations( @posts, [{ user: :site }, :stored_preferences, :parent] )
    # TODO: Rails 5 - pleary 06/30/21: I removed :site_name_short from methods as Rails 5 throws
    # an error for missing methods. We should only use methods shared by all post parent classes
    respond_to do | format |
      format.json do
        json = @posts.as_json( include: {
          user: {
            only: [:id, :login],
            methods: [:user_icon_url, :medium_user_icon_url]
          },
          parent: {
            only: [:id, :title, :name],
            methods: [:icon_url]
          }
        } )
        json.each_with_index do | post, i |
          ar_post = @posts.detect {| p | p.id == post["id"].to_i }
          json[i]["body"] = helpers.formatted_user_text(
            json[i]["body"],
            scrubber: PostScrubber.new(
              tags: Post::ALLOWED_TAGS,
              attributes: Post::ALLOWED_ATTRIBUTES
            ),
            skip_simple_format: ( ar_post.preferred_formatting == Post::FORMATTING_NONE )
          )
        end
        render json: json
      end
    end
  end

  private

  def get_archives( _options = {} )
    scope = @parent.is_a?( User ) ? @parent.journal_posts : @parent.posts
    @archives = scope.published.group( "TO_CHAR(published_at, 'YYYY MM Month')" ).count
    @archives = @archives.to_a.sort_by( &:first ).reverse.map do | month_str, count |
      [month_str.split, count].flatten
    end
  end

  def load_parent
    if params[:login]
      @display_user = User.find_by_login( params[:login] )
      @parent = @display_user
    elsif params[:project_id]
      @display_project = Project.find( params[:project_id] )
      @parent = @display_project
    end
    if @post
      @display_user ||= @post.user if @post
      @parent ||= @post.parent if @post
    elsif logged_in? && current_user.login == params[:login]
      @display_user ||= current_user
      @parent ||= current_user
    elsif params[:post] && params[:post][:parent_type] && params[:post][:parent_id]
      parent_type = params[:post][:parent_type].constantize
      @parent = parent_type.find_by_id params[:post][:parent_id] if parent_type.include? HasJournal
    else
      @parent ||= @site
    end
    return render_404 if @parent.blank?

    @selected_user = @display_user if @parent.is_a? User
    true
  end

  def load_new_post
    @post = Post.new( params[:post] )
    @post.parent ||= @parent
    @post.user ||= current_user
    true
  end

  def load_post
    @post = Post.find_by_id( params[:id] )
    render_404 and return unless @post

    if request.fullpath =~ %r{/trips}
      @post.becomes( Trip )
    end
    true
  end

  def owner_required
    return true if logged_in? && @post&.persisted? && @post&.user&.id == current_user.id
    if @parent.journal_owned_by?( current_user ) && ( @post.blank? || @post.parent == @parent )
      return true
    end

    flash[:error] = t( :you_dont_have_permission_to_do_that )
    redirect_to @parent.journal_path
    false
  end

  def path_for_post( post )
    if post.parent.is_a? Project
      project_journal_post_path( post.parent.slug, post )
    elsif post.parent.is_a? Site
      site_post_path( post )
    elsif post.is_a? Trip
      trip_path( post )
    else
      journal_post_path( post.user.login, post )
    end
  end

  def parent_path_for_post( post )
    case post.parent_type
    when "Project"
      project_journal_path( post.parent.slug )
    when "User"
      journal_by_login_path( post.user.login )
    else
      site_posts_path
    end
  end

  def edit_path_for_post( post )
    if post.parent.is_a? Project
      edit_project_journal_post_path( post.parent.slug, post )
    elsif post.is_a? Trip
      edit_trip_path( post )
    elsif post.parent.is_a? Site
      edit_site_post_path( post )
    else
      edit_journal_post_path( post.user.login, post )
    end
  end
end
