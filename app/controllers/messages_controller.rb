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
      current_user.messages.sent.order( "id desc" ).page( params[:page] )
    else
      current_user.messages.inbox.order( "id desc" ).page( params[:page] )
    end
    unless params[:user_id].blank?
      @search_user = User.find_by_id( params[:user_id] )
      @search_user ||= User.find_by_login( params[:user_id] )
      @messages = case @box
      when Message::SENT
        @messages.where( to_user_id: @search_user )
      else
        @messages.where( from_user_id: @search_user )
      end
    end
    unless params[:q].blank?
      @q = params[:q].to_s[0..100]
      @messages = @messages.where( "subject ILIKE ? OR body ILIKE ?", "%#{@q}%", "%#{@q}%" )
    end
    respond_to do |format|
      format.html do
        if params[:partial]
          render :partial => "messages"
        else
          render
        end
      end
      format.json do
        render json: {
          page: @messages.current_page,
          per_page: @messages.per_page,
          total_results: @messages.total_entries,
          results: @messages
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
          render :new
        end
      end
      format.json do
        if params[:preview]
          @message.html = view_context.formatted_user_text( @message.body )
          render json: @message.to_json( methods: [:html] )
        elsif @message.valid?
          render json: @message.as_json
        else
          render json: { errors: @message.errors }
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
    @box = Message::INBOX unless Message::BOXES.include?(@box)
  end

  def require_owner
    return true if current_user && current_user.is_admin?
    if @message.user != current_user
      msg = "You don't have permission to do that"
      respond_to do |format|
        format.html do
          flash[:error] = msg
          return redirect_back_or_default(messages_url)
        end
        format.json { render :json => {:error => msg}, status: :forbidden }
      end
    end
  end
end
