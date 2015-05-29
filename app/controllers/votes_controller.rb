class VotesController < ApplicationController
  before_action :doorkeeper_authorize!, :if => lambda { authenticate_with_oauth? }
  before_filter :authenticate_user!, :unless => lambda { authenticated_with_oauth? }
  before_filter :load_votable

  def vote
    @record.vote_by voter: current_user, vote: params[:vote], vote_scope: params[:scope]
    respond_to do |format|
      format.html do
        redirect_to @record
      end
      format.json { render json: @record.as_json(methods: [:votes]) }
    end
  end

  def unvote
    @record.unvote voter: current_user, vote: params[:vote], vote_scope: params[:scope]
    respond_to do |format|
      format.html do
        redirect_to @record
      end
      format.json { head :no_content }
    end
  end

  def for
    @users = @record.votes_for.up.by_type(User).page(params[:page]).per_page(100).voters
    @users = User.
      joins("JOIN votes ON votes.voter_type = 'User' AND votes.voter_id = users.id").
      where("votes.votable_type = ? AND votes.votable_id = ?", @record.class.name, @record.id).
      order("users.login").
      page(params[:page]).
      per_page(100)
    respond_to do |format|
      format.html do
        render partial: 'for'
      end
    end
  end

  private
  def load_votable
    klass = Object.const_get(params[:resource_type].singularize.underscore.camelcase) rescue nil
    unless klass && (@record = klass.find(params[:resource_id]) rescue nil)
      render_404
      return false
    end
  end
end
