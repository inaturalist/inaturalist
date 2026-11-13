# frozen_string_literal: true

require "spec_helper"

describe PostImage do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to( :post ).optional }

  it "is valid without a post" do
    expect( PostImage.make( post: nil ) ).to be_valid
  end

  it "requires a file" do
    expect( PostImage.make( file_file_name: nil ) ).not_to be_valid
  end

  %w(image/jpeg image/png image/gif image/webp).each do | content_type |
    it "accepts #{content_type}" do
      expect( PostImage.make( file_content_type: content_type ) ).to be_valid
    end
  end

  it "rejects other content types" do
    expect( PostImage.make( file_content_type: "application/pdf" ) ).not_to be_valid
  end

  it "rejects files over 20 MB" do
    expect( PostImage.make( file_file_size: 21.megabytes ) ).not_to be_valid
  end
end
