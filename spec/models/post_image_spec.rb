# frozen_string_literal: true

require "spec_helper"

describe PostImage do
  it { is_expected.to belong_to( :user ).required }
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

  {
    "image/jpeg" => :jpg,
    "image/webp" => :webp,
    "image/png" => :png,
    "image/gif" => :gif
  }.each do | content_type, format |
    it "stores #{content_type} styles as #{format}" do
      styles = PostImage.new( file_content_type: content_type ).file.styles
      styles.each_value {| style | expect( style.format ).to eq format }
    end
  end

  it "strips metadata from every style" do
    styles = PostImage.new( file_content_type: "image/jpeg" ).file.styles
    expect( styles.keys ).to contain_exactly( :original, :large, :medium, :small )
    styles.each_value {| style | expect( style.processors ).to include :metadata_filter }
  end

  describe "orphaned" do
    it "includes images never claimed by a post after 24 hours" do
      orphan = PostImage.make!( post: nil, created_at: 25.hours.ago )
      expect( PostImage.orphaned ).to include orphan
    end

    it "excludes unclaimed images younger than 24 hours" do
      recent = PostImage.make!( post: nil, created_at: 23.hours.ago )
      expect( PostImage.orphaned ).not_to include recent
    end

    it "excludes claimed images" do
      claimed = PostImage.make!( post: Post.make!( parent: Site.make! ), created_at: 1.week.ago )
      expect( PostImage.orphaned ).not_to include claimed
    end
  end

  describe "absolute_url" do
    let( :post_image ) { PostImage.make! }

    it "is an absolute URL containing post_images/:id/ without a timestamp" do
      %i[original large medium small].each do | style |
        url = post_image.absolute_url( style )
        expect( url ).to match %r{\Ahttps?://[^/]+/.*post_images/#{post_image.id}/#{style}\.jpg\z}
      end
    end

    it "matches BODY_URL_ID" do
      expect( post_image.absolute_url( :large ).scan( PostImage::BODY_URL_ID ).flatten ).
        to eq [post_image.id.to_s]
    end
  end

  describe "upload_json" do
    it "has the id, URLs, dimensions and metadata" do
      post_image = PostImage.make!( width: 1024, height: 768, alt: "A heron" )
      json = post_image.upload_json
      expect( json.keys ).to contain_exactly(
        :id, :original_url, :large_url, :medium_url, :small_url, :width, :height,
        :caption, :attribution, :alt
      )
      expect( json[:id] ).to eq post_image.id
      expect( json[:large_url] ).to eq post_image.absolute_url( :large )
      expect( json[:width] ).to eq 1024
      expect( json[:height] ).to eq 768
      expect( json[:alt] ).to eq "A heron"
    end
  end

  describe "dimensions", :paperclip_processing do
    it "are set from the large style" do
      post_image = PostImage.create!(
        user: User.make!,
        file: File.open( Rails.root.join( "spec/fixtures/files/cuthona_abronia-tagged.jpg" ) )
      )
      original_width, original_height = FastImage.size(
        Rails.root.join( "spec/fixtures/files/cuthona_abronia-tagged.jpg" ).to_s
      )
      expect( post_image.width ).to be <= 1024
      expect( post_image.height ).to be <= 1024
      expect( [post_image.width, post_image.height].max ).to eq [1024, original_width, original_height].min
    end
  end

  describe "alt on a published post's cover" do
    let( :post ) { Post.make!( :draft, parent: Site.make!, user: User.make!( created_at: 2.days.ago ) ) }
    let( :post_image ) { PostImage.make!( post: post, alt: "A heron" ) }

    before { post.update!( cover_image: post_image ) }

    it "can't be cleared" do
      post.update!( published_at: Time.now )
      post_image.alt = ""
      expect( post_image ).not_to be_valid
      expect( post_image.errors.added?( :alt, :required_for_published_cover ) ).to be true
    end

    it "can be changed" do
      post.update!( published_at: Time.now )
      post_image.alt = "A great blue heron"
      expect( post_image ).to be_valid
    end

    it "can be cleared on a draft's cover" do
      post_image.alt = ""
      expect( post_image ).to be_valid
    end

    it "can be cleared on a published post's body image" do
      post.update!( published_at: Time.now )
      body_image = PostImage.make!( post: post, alt: "A heron" )
      body_image.alt = ""
      expect( body_image ).to be_valid
    end
  end
end
