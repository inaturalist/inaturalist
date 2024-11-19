require File.dirname(__FILE__) + '/../spec_helper.rb'

describe LocalSound, "creation" do
  it "should convert an AMR file to M4A" do
    ls = LocalSound.create!(
      user: User.make!,
      file: File.open( File.join( Rails.root, "spec/fixtures/files/pika.amr" ) )
    )
    expect( ["audio/mp4", "audio/x-m4a"] ).to include ls.file.content_type
  end

  it "should not convert an MP3 to an MP4" do
    ls = LocalSound.create!(
      user: User.make!,
      file: File.open( File.join( Rails.root, "spec/fixtures/files/pika.mp3" ) )
    )
    expect( ["audio/mp3", "audio/mpeg"]  ).to include ls.file.content_type
  end
end

describe LocalSound, "hiding" do

  elastic_models( Observation )

  it "should make associated observations casual grade when hidden" do
    o = make_research_grade_candidate_observation
    sound = ObservationSound.make!( observation: o ).sound
    expect( o.quality_grade ).to eq Observation::NEEDS_ID
    ModeratorAction.make!( resource: sound, action: ModeratorAction::HIDE )
    o.reload
    expect( o.quality_grade ).to eq Observation::CASUAL
  end

  it "should re-index the observation" do
    o = make_research_grade_observation
    sound = ObservationSound.make!( observation: o ).sound
    original_last_indexed_at = o.last_indexed_at
    ModeratorAction.make!( resource: sound, action: ModeratorAction::HIDE )
    o.reload
    expect( o.last_indexed_at ).to be > original_last_indexed_at
  end
end
