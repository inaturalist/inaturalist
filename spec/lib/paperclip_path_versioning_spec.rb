# frozen_string_literal: true

# rubocop:disable Lint/ConstantDefinitionInBlock

require "spec_helper"

PATHS = [
  "/attachments/users/icons/:id/:style.:icon_type_extension",
  "/attachments/users/icons/:id/:icon_version-:style.:icon_type_extension"
].freeze

describe PaperclipPathVersioning do
  describe "prerequisites" do
    it "raises an error if the attachment updated_at column does not exist" do
      expect do
        class User < ApplicationRecord
          paperclip_path_versioning( :missing_field, PATHS )
        end
      end.to raise_error( "`User` cannot implement `PaperclipPathVersioning` on attachment " \
        "`missing_field` as it is missing column `missing_field_updated_at`" )
    end

    it "raises an error if the attachment path_version column does not exist" do
      expect( User ).to receive( "column_names" ).
        exactly( 2 ).times.and_return( ["missing_field_updated_at"] )
      expect do
        class User < ApplicationRecord
          paperclip_path_versioning( :missing_field, PATHS )
        end
      end.to raise_error( "`User` cannot implement `PaperclipPathVersioning` on attachment " \
        "`missing_field` as it is missing column `missing_field_path_version`" )
    end
  end

  describe "implemented" do
    before :all do
      class User < ApplicationRecord
        paperclip_path_versioning( :icon, PATHS )
      end
    end

    it "sets attachment paths as a class constant" do
      expect( User::PAPERCLIP_ICON_PATHS ).to eq [
        "/attachments/users/icons/:id/:style.:icon_type_extension",
        "/attachments/users/icons/:id/:icon_version-:style.:icon_type_extension"
      ]
    end

    describe "paperclip_versioned_path" do
      it "returns the path corresponding to the attaachment version" do
        expect( User.make!( icon_path_version: 0 ).
          paperclip_versioned_path( :icon ) ).to eq PATHS[0]
        expect( User.make!( icon_path_version: 1 ).
          paperclip_versioned_path( :icon ) ).to eq PATHS[1]
      end
    end

    describe "updating path version" do
      it "updates the attachment path version when the attachment is updated" do
        u = User.make!( icon_path_version: 0 )
        expect( u.icon_path_version ).to eq 0
        expect( u ).to receive( "icon_updated_at_changed?" ).and_return( true )
        u.save
        expect( u.icon_path_version ).to eq 1
      end
    end

    describe "attachment version" do
      it "returns a hash of the attachment updated_at column as the attachment version" do
        time = Time.now
        u = User.make!( icon_updated_at: time )
        expect( u.icon_version ).to eq Digest::MD5.hexdigest( time.to_i.to_s )
      end
    end
  end
end

# rubocop:enable Lint/ConstantDefinitionInBlock
