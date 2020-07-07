require "spec_helper"

describe "photos/show" do
  it "includes image metadata" do
    p = LocalPhoto.make!
    p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "polistes_dominula-png-metadata.png" ) )
    p.extract_metadata
    
    assign( :size, "medium" )
    assign( :photo, p )

    render
    
    expect(rendered).to have_tag( "tr" ) do
      with_tag "th", text: "Copyright"
      with_tag( "td" ) { with_tag "p", text: /all rights reserved/ }
    end
  end
end
