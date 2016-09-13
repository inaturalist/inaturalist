class ControlledTermsController < ApplicationController

  before_filter :authenticate_user!
  before_filter :admin_required

  def index
    render
  end

  def create
    term = ControlledTerm.new(params[:controlled_term])
    term.save
    redirect_to :controlled_terms
  end

  def edit
    @term = ControlledTerm.find(params[:id])
  end

  def update
    term = ControlledTerm.find(params[:id])
    term.update_attributes(params[:controlled_term])
    redirect_to :controlled_terms
  end

  def destroy
    term = ControlledTerm.find(params[:id])
    term.destroy
    redirect_to :controlled_terms
  end

end
