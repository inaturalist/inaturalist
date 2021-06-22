class MessagesController < ApplicationController
  before_action :doorkeeper_authorize!,
    only: [ :index, :create, :show, :destroy, :count ],
    if: lambda { authenticate_with_oauth? }
  before_filter :authenticate_user!, unless: lambda { authenticated_with_oauth? }
  before_filter :load_message, :only => [:show, :destroy]
  before_filter :require_owner, :only => [:show, :destroy]
  before_filter :load_box, :only => [:show, :new, :index]
  check_spam only: [:create, :update], instance: :message

  requires_privilege :speech, only: [:new]

  layout "bootstrap"

  def index
    @messages = case @box
    when Message::SENT
      current_user.messages.sent
    when "any"
      current_user.messages
    else
      current_user.messages.inbox
    end
    unless params[:user_id].blank?
      @search_user = User.find_by_id( params[:user_id] )
      @search_user ||= User.find_by_login( params[:user_id] )
      @messages = case @box
      when Message::SENT
        @messages.where( to_user_id: @search_user )
      when "any"
        @messages.where( "to_user_id = ? OR from_user_id = ?", @search_user, @search_user )
      else
        @messages.where( from_user_id: @search_user )
      end
    end
    if params[:threads].yesish?
      unless params[:q].blank?
        error_message = "Search will not work when grouping by thread"
        respond_to do |format|
          format.html do
            flash[:error] = error_message
            redirect_back_or_default messages_path
          end
          format.json do
            render json: { errors: [error_message] }, status: :unprocessable_entity
          end
        end
        return
      end
      threads_scope = @messages.select( "max(id) AS latest_id, thread_id, COUNT(id) AS thread_messages_count" ).group( "thread_id" )
      @messages = Message.
        select( "messages.*, threads.thread_messages_count" ).
        from( "(#{threads_scope.to_sql}) AS threads" ).
        joins( "JOIN messages AS messages ON messages.id = threads.latest_id" )
    end
    unless params[:q].blank?
      @q = params[:q].to_s[0..100]
      @messages = @messages.joins( "JOIN users ON users.id = from_user_id" ).
        where( "subject ILIKE ? OR body ILIKE ? OR users.name ILIKE ? OR users.login = ?", "%#{@q}%", "%#{@q}%", "%#{@q}%", @q )
    end
    @messages = @messages.order( "id desc" ).page( params[:page] ).includes( :from_user, :to_user )
    respond_to do |format|
      format.html do
        if params[:partial]
          render :partial => "messages"
        else
          render
        end
      end
      format.json do
        results = @messages.map do |m|
          merges = {
            from_user: m.from_user&.as_json( only: [:id, :login] ),
            to_user: m.to_user&.as_json( only: [:id, :login] ),
          }
          if params[:threads].yesish?
            merges[:thread_flags] = m.thread_flags.map{|f| f.as_indexed_json}
          end
          m.as_json.merge( merges )
        end
        render json: {
          page: @messages.current_page,
          per_page: @messages.per_page,
          total_results: @messages.total_entries,
          results: results
        }
      end
    end
  end

  def sent
    @messages = current_user.messages.sent.page(params[:page])
  end

  def show
    @messages = Message.where( user_id: @message.user_id, thread_id: @message.thread_id ).order( "id asc" )
    if current_user.is_admin? && current_user.id != @message.user_id
      flash.now[:notice] =  "You can see this because you're on staff. Please be careful"
    else
      Message.where( id: @messages, read_at: nil ).update_all( read_at: Time.now )
    end
    @thread_message = @messages.first
    @reply_to = @thread_message.from_user == current_user ? @thread_message.to_user : @thread_message.from_user
    @flaggable_message = if m = @messages.detect{|m| m.from_user && m.from_user != current_user}
      m.from_user.messages.where(:thread_id => @message.thread_id).first
    end
    if @flaggable_message && @flaggable_message.flagged?
      @flag = @flaggable_message.flags.detect{|f| f.user_id == current_user.id }
    end
    @new_correspondent = !Message.
      where( from_user_id: current_user, to_user_id: @reply_to ).
      exists?
    respond_to do |format|
      format.html
      format.json do
        render json: {
          page: 1,
          per_page: @messages.count,
          total_results: @messages.count,
          thread_id: @thread_message.id,
          reply_to_user_id: @reply_to.id,
          flaggable_message_id: @flaggable_message.try(:id),
          results: @messages.as_json
        }
      end
    end
  end

  def new
    # unless current_user.privileged_with?( UserPrivilege::SPEECH )
    #   flash[:notice] = t( "errors.messages.requires_privilege_speech" )
    #   redirect_back_or_default( messages_path )
    # end
    @message = current_user.messages.build
    @contacts = User.
      select("DISTINCT ON (users.id) users.*").
      joins("JOIN messages ON messages.to_user_id = users.id").
      where("messages.from_user_id = ?", current_user).
      limit(100)
    @contacts = current_user.followees.limit(100) if @contacts.blank?
    unless @contacts.blank?
      @contacts.each_with_index do |u,i|
        @contacts[i].html = view_context.render_in_format(:html, :partial => "users/chooser", :object => u).gsub(/\n/, '')
      end
    end
    unless params[:to].blank?
      @message.to_user = User.find_by_login(params[:to])
      @message.to_user ||= User.find_by_id(params[:to])
    end
  end

  def create
    @message = current_user.messages.build(params[:message])
    @message.user = current_user
    @message.from_user = current_user
    unless params[:preview]
      if @message.save
        @message.send_message
      end
    end

    respond_to do |format|
      format.html do
        if @message.valid?
          redirect_to @message
        else
          render :new, status: :unprocessable_entity
        end
      end
      format.json do
        if params[:preview]
          @message.html = view_context.formatted_user_text( @message.body )
          render json: @message.to_json( methods: [:html] )
        elsif @message.valid?
          render json: @message.as_json
        else
          render json: { errors: @message.errors }, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    thread_messages = Message.where(
      "user_id = ? AND thread_id = ?",
      current_user.id, @message.thread_id
    )
    if thread_messages.blank?
      return render_404
    else
      thread_messages.destroy_all
      msg = t(:message_deleted)
      respond_to do |format|
        format.html do
          flash[:notice] = msg
          redirect_to messages_url
        end
        format.json { head :no_content }
      end
    end
  end

  def count
    count = current_user.messages.inbox.unread.count
    session[:messages_count] = count
    respond_to do |format|
      format.json do
        render json: { count: count }
      end
    end
  end

  def new_messages
    @messages = current_user.messages.inbox.includes(:from_user).unread.order("id desc").limit(200)
    @messages = current_user.messages.inbox.includes(:from_user).order("id desc").limit(7) if @messages.blank?
    session[:messages_count] = 0
    render :layout => false
  end

  private
  def load_message
    render_404 unless @message = Message.find_by_id(params[:id])
  end

  def load_box
    @box = params[:box]
    @box = Message::INBOX unless Message::BOXES.include?(@box) || @box == "any"
  end

  def require_owner
    return true if current_user && current_user.is_admin?
    if @message.user != current_user
      msg = I18n.t(:you_dont_have_permission_to_do_that)
      respond_to do |format|
        format.html do
          flash[:error] = msg
          return redirect_back_or_default(messages_url)
        end
        format.json { render json: { error: msg}, status: :forbidden }
      end
    end
  end
end
