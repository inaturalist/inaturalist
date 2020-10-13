class NotificationsController < ApplicationController

  before_filter :admin_required
  before_filter :load_user_by_login, only: [ :by_login ]
  before_filter :load_record, only: [ :mark_as_read, :mark_as_unread ]

  def by_login
    category = params[:category] || :conversations
    @notifications = Notification.where( user: @selected_user ).
      where( category: category ).
      order( notifier_date: :desc ).
      paginate( page: params[:page] )
    @json = {
      notifications: @notifications.as_json,
      category_counts: Notification.
        joins( :notifications_notifiers ).
        where( "notifications_notifiers.read_at IS NULL" ).
        where( user: @selected_user ).
        group( :category ).uniq.count
    }
    Notification.mark_as_viewed( @notifications )
    respond_to do |format|
      format.html do
        render layout: "bootstrap"
      end
      format.json do
        render json: @json
      end
    end
  end

  def mark_as_read
    @notification.mark_as_read
    redirect_to notifications_by_login_path( login: @notification.user.login,
      category: @notification.category )
  end

  def mark_as_unread
    @notification.mark_as_unread
    redirect_to notifications_by_login_path( login: @notification.user.login,
      category: @notification.category )
  end

end
