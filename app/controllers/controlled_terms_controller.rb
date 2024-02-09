class ControlledTermsController < ApplicationController
  before_action :authenticate_user!
  before_action :admin_required

  def index
    render
  end

  def create
    label_attrs = params[:controlled_term].delete( :controlled_term_label )
    term = ControlledTerm.new( params[:controlled_term] )
    controlled_term_label = term.labels.build( label_attrs )
    term.user = current_user
    if term.save
      if label_attrs
        term.labels << controlled_term_label
      end
    else
      flash[:error] = term.errors.full_messages.to_sentence
      if term.errors[:labels] && !controlled_term_label.valid?
        flash[:error] = controlled_term_label.errors.full_messages.join( ", " )
      end
    end

    redirect_to :controlled_terms
  end

  def edit
    @term = ControlledTerm.find(params[:id])
  end

  def update
    if label_attrs = params[:controlled_term].delete(:controlled_term_label)
      existing = ControlledTermLabel.where(id: label_attrs[:id]).first
      if existing
        existing.update(label_attrs)
      else
        ControlledTermLabel.create(label_attrs)
      end
    end

    term = ControlledTerm.find(params[:id])
    unless term.update(params[:controlled_term])
      flash[:error] = term.errors.full_messages.to_sentence
    end
    redirect_to :controlled_terms
  end

  def destroy
    term = ControlledTerm.find(params[:id])
    term.destroy
    redirect_to :controlled_terms
  end

end
