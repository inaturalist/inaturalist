# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe ListsController, "by_login" do
  render_views

  let( :user ) { create :user }
  before { sign_in user }

  it "should load" do
    list = create( :list, user: user )
    expect( list ).to be_valid
    get :by_login, params: { login: user.login }
    expect( response ).to be_successful
  end
end
