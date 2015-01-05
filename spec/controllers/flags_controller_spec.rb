require File.dirname(__FILE__) + '/../spec_helper'

describe FlagsController do

  # These are crazy simple tests, but we do rely on the values of these
  # constants elsewhere, so I figured some tests couldn't hurt
  it "should have the right FLAG_MODELS" do
    FLAG_MODELS = [ "Observation", "Taxon", "Post", "Comment",
      "Identification", "Message", "Photo", "List", "Project" ]
  end

  it "should have the right FLAG_MODELS_ID" do
    FLAG_MODELS_ID = [ "observation_id","taxon_id","post_id", "comment_id",
      "identification_id", "message_id", "photo_id", "list_id", "project_id" ]
  end

end
