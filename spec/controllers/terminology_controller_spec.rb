# frozen_string_literal: true

require "spec_helper"

describe TerminologyController do
  render_views
  it "should render" do
    get :index
    expect( response.body ).to match /Terminology/
  end
end
