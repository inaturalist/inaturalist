# frozen_string_literal: true

require "spec_helper"
require "rake"

describe "inaturalist:delete_orphaned_post_images" do
  before( :all ) do
    Rake.application = Rake::Application.new
    Rake.application.rake_require( "tasks/inaturalist", ["#{Rails.root}/lib"] )
    Rake::Task.define_task( :environment )
  end

  let( :task ) { Rake::Task["inaturalist:delete_orphaned_post_images"] }

  before do
    task.reenable
  end

  it "deletes images never claimed by a post 24 hours after upload" do
    orphan = PostImage.make!( post: nil, created_at: 25.hours.ago )
    expect { task.invoke }.to output.to_stdout
    expect( PostImage.find_by_id( orphan.id ) ).to be_nil
  end

  it "deletes the orphan's files" do
    orphan = PostImage.make!( post: nil, created_at: 25.hours.ago )
    expect_any_instance_of( Paperclip::Attachment ).to receive( :queue_all_for_delete ).and_call_original
    expect { task.invoke }.to output.to_stdout
    expect( PostImage.find_by_id( orphan.id ) ).to be_nil
  end

  it "keeps unclaimed images younger than 24 hours" do
    recent = PostImage.make!( post: nil, created_at: 23.hours.ago )
    expect { task.invoke }.to output.to_stdout
    expect( PostImage.find_by_id( recent.id ) ).not_to be_nil
  end

  it "keeps claimed images" do
    claimed = PostImage.make!( post: Post.make!( parent: Site.make! ), created_at: 1.week.ago )
    expect { task.invoke }.to output.to_stdout
    expect( PostImage.find_by_id( claimed.id ) ).not_to be_nil
  end
end
