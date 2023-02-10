class FlagsController < ApplicationController
  before_action :doorkeeper_authorize!, if: lambda { authenticate_with_oauth? }, except: [:show]
  before_action :authenticate_user!, unless: lambda { authenticated_with_oauth? }, except: [:show]
  before_action :set_model, except: [:update, :show, :destroy, :on]
  before_action :model_required, except: [:index, :update, :show, :on, :destroy]
  before_action :load_flag, only: [:show, :destroy, :update]
  before_action :check_update_permissions, only: [:update]

  PARTIALS = %w(dialog)

  def index
    if request.path != "/flags" && @model
      @object = find_object
      if @object
        # The default acts_as_flaggable index route
        @object = @object.becomes(Photo) if @object.is_a?(Photo)
        @object = @object.becomes(Sound) if @object.is_a?(Sound)
        @flags = @object.flags.includes(:user, :resolver).
          paginate(page: params[:page]).
          order(id: :desc)
        @unresolved = @flags.select {|f| not f.resolved }
        @resolved = @flags.select {|f| f.resolved }
        @moderator_actions = if @object.respond_to?(:moderator_actions)
          @object.moderator_actions.limit( 100 ).to_a
        end
        respond_to do |format|
          format.html { render layout: "bootstrap" }
        end
        return
      end
    end
    # a real index of all flags, which can be filtered by flag type
    @flag_type = params[:flag].to_s.tr("_", " ")
    @flag_types = [params[:flags]].flatten.compact
    @flag_types = ["other", Flag::INAPPROPRIATE] if @flag_types.blank?
    @resolved = if params[:resolved].blank?
      "no"
    elsif params[:resolved] == "any"
      "any"
    elsif params[:resolved].yesish?
      "yes"
    elsif params[:resolved].noish?
      "no"
    end
    @deleted = if params[:deleted].blank?
      "any"
    elsif params[:deleted] == "any"
      "any"
    elsif params[:deleted].yesish?
      "yes"
    elsif params[:deleted].noish?
      "no"
    end
    @flaggable_type = params[:flaggable_type] if Flag::TYPES.include?( params[:flaggable_type] )
    @user = User.where( login: params[:user_id] ).first || User.where( id: params[:user_id] ).first
    @user ||= User.where( login: params[:user_name] ).first
    @resolver = User.where( login: params[:resolver_id] ).first || User.where( id: params[:resolver_id] ).first
    @resolver ||= User.where( login: params[:resolver_name] ).first
    @flagger_type = params[:flagger_type] if %w(any auto user).include?( params[:flagger_type] )
    @flagger_type ||= "any"
    @taxon = Taxon.find_by_id( params[:taxon_id] )
    @flags = Flag.order( "created_at desc" )
    @flags = @flags.where( flaggable_user_id: @user.id ) if @user
    unless @flag_type.blank?
      @flags = @flags.where(flag: @flag_type)
    end
    @flags = @flags.where( flaggable_type: @flaggable_type ) unless @flaggable_type.blank?
    if @flag_types.include?( "other" )
      except_flag_types = Flag::FLAGS - @flag_types
      unless except_flag_types.blank?
        @flags = @flags.where( "flag NOT IN (?)", ( Flag::FLAGS - @flag_types ) )
      end
    else
      @flags = @flags.where( "flag IN (?)", @flag_types )
    end
    if @resolved == "yes"
      @flags = @flags.where( "resolved" )
    elsif @resolved == "no"
      @flags = @flags.where( "NOT resolved" )
    end
    if @flaggable_type
      if @deleted == "yes"
        flaggable_klass = Object.const_get( @flaggable_type )
        @flags = @flags.
          joins( "LEFT JOIN #{flaggable_klass.table_name} ON #{flaggable_klass.table_name}.id = flags.flaggable_id" ).
          where( "#{flaggable_klass.table_name}.id IS NULL" )
      elsif @deleted == "no"
        flaggable_klass = Object.const_get( @flaggable_type )
        @flags = @flags.
          joins( "LEFT JOIN #{flaggable_klass.table_name} ON #{flaggable_klass.table_name}.id = flags.flaggable_id" ).
          where( "#{flaggable_klass.table_name}.id IS NOT NULL" )
      end
    end
    if @flagger_type == "auto"
      @flags = @flags.where( "flags.user_id = 0 OR flags.user_id IS NULL" )
    elsif @flagger_type == "user"
      @flagger = User.find_by_id( params[:flagger_user_id] )
      @flagger ||= User.find_by_login( params[:flagger_name] )
      if @flagger
        @flags = @flags.where( "flags.user_id = ?", @flagger )
      end
    end
    if @taxon && @flaggable_type == "Taxon"
      @flags = @flags.
        joins( "JOIN taxa ON (taxa.id = flags.flaggable_id AND #{@taxon.subtree_conditions.to_sql})" )
    end
    if @resolver
      @flags = @flags.where( resolver_id: @resolver )
    end
    if @reason_query = params[:reason_query]
      @flags = @flags.where( "flag ILIKE ?", "%#{@reason_query}%" )
    end
    @flags = @flags.paginate(per_page: 50, page: params[:page])
    render :global_index, layout: "bootstrap"
  end

  def show
    @object = @flag.flagged_object
    @object = @object.becomes(Photo) if @object.is_a?(Photo)
    @object = @object.becomes(Sound) if @object.is_a?(Sound)
    user_viewed_updates_for( @flag ) if logged_in?
    respond_to do |format|
      format.html { render layout: "bootstrap" }
    end
  end

  def new
    @flag = Flag.new(params[:flag])
    @object = @model.find(params[@object_key])
    @object = @object.becomes(Photo) if @object.is_a?(Photo)
    @flag.flaggable ||= @object
    @flags = @object.flags.where(resolved: false).includes(:user)
    if PARTIALS.include?(params[:partial])
      render :layout => false, :partial => params[:partial]
      return
    end
  end

  def create
    create_options = params[:flag]
    create_options[:user_id] = current_user.id
    @object = @model.find_by_id(params[:flag][:flaggable_id])
    unless @object
      flash[:error] = t(:cant_flag_an_object_that_doesnt_exist)
      redirect_to root_path
    end

    @create_comment = false
    if @flag = Flag.where( create_options.except( "initial_comment_body" ) ).where( resolved: true ).first
      @flag.resolved = false
    else
      @flag = @object.flags.build(create_options)
      @create_comment = create_options.key?( :initial_comment_body ) && create_options[:initial_comment_body].length > 0
      if @create_comment
        @comment_attributes = { parent: @flag, user: current_user, body: create_options[:initial_comment_body] }
        @flag.comments.build( @comment_attributes )
      end
    end
    if @flag.flag == "other" && !params[:flag_explanation].blank?
      @flag.flag = params[:flag_explanation]
    end

    if @flag.save
      flash[:notice] = t( :flag_saved_thanks_html, url: url_for( @flag ) )
      if @create_comment && Comment.where( @comment_attributes ).length == 0
        flash[:notice] << " " + t( :unable_to_save_comment )
      end
    else
      flash[:error] = t(:we_had_a_problem_flagging_that_item, :flag_error => @flag.errors.full_messages.to_sentence.downcase)
    end

    if @object.is_a?(Project)
      Project.refresh_es_index
    end

    respond_to do |format|
      format.html do
        if @object.is_a?(Comment)
          redirect_to @object.parent
        elsif @object.is_a?(Identification)
          redirect_to @object.observation
        elsif @object.is_a?(Message)
          redirect_to messages_path
        elsif @object.is_a?(Photo)
          redirect_to @object.becomes(Photo)
        else
          redirect_to @object
        end
      end
      format.json do
        if @flag.valid?
          render json: @flag
        else
          render status: :unprocessable_entity, json: @flag.errors
        end
      end
    end


  end

  def update
    if resolver_id = params[:flag].delete("resolver_id")
      params[:flag]["resolver"] = User.find_by_id(resolver_id)
    end
    respond_to do |format|
      msg = begin
        if @flag.update(params[:flag])
          t(:flag_saved)
        else
          t(:we_had_a_problem_flagging_that_item, :flag_error => @flag.errors.full_messages.to_sentence)
        end
      rescue Photo::MissingPhotoError
        "Flag resolved, but the photo in question is gone and cannot be restored"
      end
      if @object.is_a?(Project)
        Project.refresh_es_index
      end
      format.html do
        flash[:notice] = msg
        redirect_back_or_default(@flag)
      end
      format.json do
        if @flag.valid?
          render json: @flag
        else
          render status: :unprocessable_entity, json: @flag.errors
        end
      end
    end

  end

  def destroy
    unless @flag.deletable_by?( current_user )
      msg = t(:you_dont_have_permission_to_do_that)
      respond_to do |format|
        format.html do
          flash[:error] = msg
          if session[:return_to] == request.fullpath
            redirect_to root_url
          else
            redirect_back_or_default( root_url )
          end
        end
        format.json do
          render status: :unprocessable_entity, json: { error: msg }
        end
      end
      return
    end
    @object = @flag.flaggable
    @flag.destroy
    if @object.is_a?(Project)
      Project.refresh_es_index
    end
    respond_to do |format|
      format.html do
        flash[:notice] = t(:flag_deleted)
        redirect_back_or_default( flags_path )
      end
      format.json do
        head :ok
      end
    end
  end

  private

  def load_flag
    render_404 unless @flag = Flag.where(id: params[:id] || params[:flag_id]).includes(:user, :resolver).first
  end

  def find_object
    object = @model.find_by_uuid(params[@object_key]) if @model.respond_to?(:find_by_uuid)
    object ||= @model.find_by_slug(params[@object_key]) if @model.respond_to?(:find_by_slug)
    object ||= @model.find_by_id( params[@object_key] )
  end

  def set_model
    @object_key = (params.keys & Flag::TYPES.map(&:foreign_key)).first
    @model = @object_key.split("_id")[0].classify.constantize if @object_key
    @model ||= Object.const_get(params[:flag][:flaggable_type]) rescue nil
  end

  def model_required
    unless @model
      flash[:notice] = t(:you_cant_flag_that)
      redirect_to observations_path
    end
  end

  def check_update_permissions
    unless logged_in? && @flag && ( current_user.is_curator? || current_user.id == @flag.user.id ) &&
        ( current_user.id != @flag.flaggable_user_id || @flag.flaggable_type == "Taxon" )
      flash[:error] = t( :you_dont_have_permission_to_do_that )
      if session[:return_to] == request.fullpath
        redirect_to root_url
      else
        redirect_back_or_default( root_url )
      end
    end
  end
end
