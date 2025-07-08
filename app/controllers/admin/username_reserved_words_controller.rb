# frozen_string_literal: true

module Admin
  class UsernameReservedWordsController < ApplicationController
    before_action :authenticate_user!
    before_action :admin_required
    before_action :load_record, only: [:destroy]

    layout "admin"

    def index; end

    def create
      UsernameReservedWord.create( word: params[:word] )
      render action: "index"
    end

    def destroy
      @username_reserved_word.destroy
      redirect_to admin_username_reserved_words_path
    end

    private

    def load_record( options = {} )
      super( options.merge( klass: UsernameReservedWord ) )
    end
  end
end
