# frozen_string_literal: true

require "spec_helper"

describe "photos/show" do
  it "includes image metadata" do
    p = LocalPhoto.make!
    p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "polistes_dominula-png-metadata.png" ) )
    p.extract_metadata

    assign( :size, "medium" )
    assign( :photo, p )

    render

    expect( rendered ).to have_tag( "tr" ) do
      with_tag "th", text: "Copyright"
      with_tag( "td" ) { with_tag "p", text: /all rights reserved/ }
    end
  end

  it "shows curators a links to original for copyright flagged photos" do
    p = LocalPhoto.make!
    Flag.make!( flag: Flag::COPYRIGHT_INFRINGEMENT, flaggable: p )

    p.update( file_extension: FileExtension.make!( extension: "new_extension" ) )
    expect( p.original_url ).to include( "copyright-infringement" )
    expect( p.file( :original ) ).not_to include( "copyright-infringement" )
    expect( p.original_url( bypass_flags: true ) ).not_to include( "copyright-infringement" )
    expect( p.original_url( bypass_flags: true ) ).not_to eq( p.file( :original ) )

    assign( :size, "medium" )
    assign( :photo, p )
    assign( :flags, p.flags )
    allow( view ).to receive( :current_user ).and_return( make_curator )
    allow( view ).to receive( :logged_in? ).and_return( true )

    render

    expect( rendered ).to have_tag(
      "p",
      text: /You can view the original at.* #{p.original_url( bypass_flags: true )}/
    )
    expect( rendered ).not_to have_tag(
      "p",
      text: /You can view the original at.* #{p.file( :original )}/
    )
  end
end
