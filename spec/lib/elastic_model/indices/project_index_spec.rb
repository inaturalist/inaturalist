require "spec_helper"

describe "Project Index" do
  let(:project) { Project.make! }
  it "as_indexed_json should return a hash" do
    json = project.as_indexed_json
    expect( json ).to be_a Hash
    expect( json[:title] ).to eq project.title
  end

  # We don't index icon at all if there's no icon, not sure how this ever worked
  # it "indexes icons with absolute URLs" do
  #   p = Project.make!
  #   json = p.as_indexed_json
  #   expect( json[:icon] ).to include Site.default.url
  # end

  it "should index as spam if project is spam" do
    expect( project.as_indexed_json[:spam] ).to be false
    Flag.make!( flag: Flag::SPAM, flaggable: project )
    project.reload
    expect( project ).to be_known_spam
    expect( project.as_indexed_json[:spam] ).to be true
  end
  
  it "should index as spam if project owned by a spammer" do
    expect( project.as_indexed_json[:spam] ).to be false
    Flag.make!( flag: Flag::SPAM, flaggable: project.user )
    project.reload
    expect( project.user ).to be_known_spam
    expect( project ).to be_owned_by_spammer
    expect( project.as_indexed_json[:spam] ).to be true
  end
end
