class MessagesController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_message, :only => [:show, :destroy]
  before_filter :require_owner, :only => [:show, :destroy]
  before_filter :load_box, :only => [:show, :new, :index]

  def index
    @messages = case @box
    when Message::SENT
      current_user.messages.sent.order("id desc").page(params[:page])
    else
      current_user.messages.inbox.order("id desc").page(params[:page])
    end
    if params[:partial]
      render :partial => "messages"
    else
      render
    end
  end

  def sent
    @messages = current_user.messages.sent.page(params[:page])
  end

  def show
    @messages = current_user.messages.where(:thread_id => @message.thread_id).order("id asc")
    Message.where(id: @messages, read_at: nil).update_at(read_at: Time.now)
    @thread_message = @messages.first
    @reply_to = @thread_message.from_user == current_user ? @thread_message.to_user : @thread_message.from_user
    @flaggable_message = if m = @messages.detect{|m| m.from_user && m.from_user != current_user}
      m.from_user.messages.where(:thread_id => @message.thread_id).first
    end
  end

  def new
    @message = current_user.messages.build
    @contacts = User.
      select("DISTINCT ON (users.id) users.*").
      joins("JOIN messages ON messages.to_user_id = users.id").
      where("messages.from_user_id = ?", current_user).
      limit(100).compact
    @contacts = current_user.friends.limit(100) if @contacts.blank?
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
    @message.save unless params[:preview]

    respond_to do |format|
      format.html do
        if @message.valid?
          @message.send_message
          redirect_to @message
        else
          render :new
        end
      end
      format.json do
        if params[:preview]
          @message.html = view_context.formatted_user_text(@message.body)
        end
        render :json => @message.to_json(:methods => [:html])
      end
    end
  end

  # def edit
  # end

  # def update
  #   @message.update_attributes
  # end

  def destroy
    Message.where("user_id = ? AND thread_id = ?", current_user.id, @message.thread_id).each(&:destroy)
    msg = "Message deleted"
    respond_to do |format|
      format.html do
        flash[:notice] = msg
        redirect_to messages_url
      end
    end
  end

  def count
    count = current_user.messages.inbox.unread.count
    session[:messages_count] = count
    render :json => {:count => count}
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
    if @message.user != current_user
      msg = "You don't have permission to do that"
      respond_to do |format|
        format.html do
          flash[:error] = msg
          return redirect_back_or_default(messages_url)
        end
        format.json { render :json => {:error => msg} }
      end
    end
  end
end
