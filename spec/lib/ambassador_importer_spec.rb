# frozen_string_literal: true

require "spec_helper"

describe AmbassadorImporter do
  def csv_file( rows )
    file = Tempfile.new( ["ambassadors", ".csv"] )
    file.write( ( ["user_id,login,ambassador_since"] + rows ).join( "\n" ) )
    file.close
    file.path
  end

  let( :user ) { User.make! }

  it "sets ambassador_since for users matched by id" do
    AmbassadorImporter.import( csv_file( ["#{user.id},,2026-08-15"] ) )
    expect( user.reload.ambassador_since ).to eq Date.new( 2026, 8, 15 )
  end

  it "falls back to login when the id does not match" do
    AmbassadorImporter.import( csv_file( ["0,#{user.login},August 2026"] ) )
    expect( user.reload.ambassador_since ).to eq Date.new( 2026, 8, 1 )
  end

  it "accepts headers in any case with surrounding whitespace" do
    path = csv_file( [] )
    File.write( path, " User_ID , Login , Ambassador_Since \n#{user.id},,2026-08-15\n" )
    AmbassadorImporter.import( path )
    expect( user.reload.ambassador_since ).to eq Date.new( 2026, 8, 15 )
  end

  it "clears ambassadors who are not in the new list" do
    former = User.make!( ambassador_since: Date.new( 2025, 1, 1 ) )
    AmbassadorImporter.import( csv_file( ["#{user.id},,2026-08-15"] ) )
    expect( former.reload.ambassador_since ).to be_nil
  end

  it "reports unmatched rows and invalid dates without aborting" do
    rows = [
      "0,nobody-by-this-login,2026-08-15",
      "#{user.id},,not a date",
      "#{User.make!.id},,2026-08-15"
    ]
    result = AmbassadorImporter.import( csv_file( rows ) )
    expect( result[:imported] ).to eq 1
    expect( result[:unmatched].size ).to eq 1
    expect( result[:invalid_dates].size ).to eq 1
    expect( user.reload.ambassador_since ).to be_nil
  end

  describe "with an invalid CSV" do
    let!( :former ) { User.make!( ambassador_since: Date.new( 2025, 1, 1 ) ) }

    it "raises and changes nothing when a header is missing" do
      path = csv_file( [] )
      File.write( path, "userid,login,ambassador_since\n#{user.id},,2026-08-15\n" )
      expect { AmbassadorImporter.import( path ) }.to raise_error( AmbassadorImporter::InvalidCSV, /user_id/ )
      expect( former.reload.ambassador_since ).to eq Date.new( 2025, 1, 1 )
    end

    it "raises and changes nothing when the file is empty" do
      path = csv_file( [] )
      File.write( path, "" )
      expect { AmbassadorImporter.import( path ) }.to raise_error( AmbassadorImporter::InvalidCSV )
      expect( former.reload.ambassador_since ).to eq Date.new( 2025, 1, 1 )
    end

    it "raises and changes nothing when no rows can be imported" do
      path = csv_file( ["0,nobody-by-this-login,2026-08-15", "#{user.id},,not a date"] )
      expect { AmbassadorImporter.import( path ) }.to raise_error( AmbassadorImporter::InvalidCSV )
      expect( former.reload.ambassador_since ).to eq Date.new( 2025, 1, 1 )
      expect( user.reload.ambassador_since ).to be_nil
    end
  end

  it "changes nothing on a dry run" do
    former = User.make!( ambassador_since: Date.new( 2025, 1, 1 ) )
    result = AmbassadorImporter.import( csv_file( ["#{user.id},,2026-08-15"] ), dry: true )
    expect( result[:imported] ).to eq 1
    expect( user.reload.ambassador_since ).to be_nil
    expect( former.reload.ambassador_since ).to eq Date.new( 2025, 1, 1 )
  end
end
