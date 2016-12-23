class ControlledTermValuesController < ApplicationController

  before_filter :authenticate_user!
  before_filter :admin_required

  def create
    val = ControlledTermValue.new(params[:controlled_term_value])
    val.save
    redirect_to val.controlled_value ?
      edit_controlled_term_path(val.controlled_value) : :controlled_terms
  end

  def destroy
    val = ControlledTermValue.find(params[:id])
    val.destroy
    redirect_to val.controlled_value ?
      edit_controlled_term_path(val.controlled_value) : :controlled_terms
  end

end
