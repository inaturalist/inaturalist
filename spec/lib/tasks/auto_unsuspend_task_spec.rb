# frozen_string_literal: true

require "spec_helper"
require "rake"

describe "inaturalist:auto_unsuspend" do
  before( :all ) do
    Rake.application = Rake::Application.new
    Rake.application.rake_require( "tasks/inaturalist", ["#{Rails.root}/lib"] )
    Rake::Task.define_task( :environment )
  end

  let( :task ) { Rake::Task["inaturalist:auto_unsuspend"] }

  before do
    task.reenable
  end

  it "does not unsuspend users whose suspension has not expired" do
    active_suspension = User.make!( suspended_at: 1.day.ago, suspended_until: 1.day.from_now )

    indefinite_suspension = User.make!( suspended_at: 1.day.ago, suspended_until: nil )

    task.invoke

    active_suspension.reload
    indefinite_suspension.reload
    expect( active_suspension ).to be_suspended
    expect( indefinite_suspension ).to be_suspended
  end

  it "creates a ModeratorAction record for each unsuspended user" do
    user = User.make!( suspended_at: 2.days.ago, suspended_until: 1.day.ago )

    expect { task.invoke }.to change( ModeratorAction, :count ).by( 1 )

    user.reload
    expect( user ).not_to be_suspended
    expect( user.suspended_until ).to be_nil

    action = ModeratorAction.last
    expect( action.action ).to eq ModeratorAction::UNSUSPEND
    expect( action.resource ).to eq user
    expect( action.user ).to be_nil
    expect( action.reason ).to eq "Timed suspension expired automatically"
  end
end
