# frozen_string_literal: true

require "spec_helper"

describe PostImagesController do
  let( :user ) { User.make!( created_at: 2.days.ago ) }
  let( :file ) { fixture_file_upload( "cuthona_abronia-tagged.jpg", "image/jpeg" ) }

  describe "create" do
    it "requires a logged-in user" do
      expect do
        post :create, format: :json, params: { file: file }
      end.not_to change( PostImage, :count )
      expect( response ).to have_http_status :unauthorized
    end

    describe "when logged in" do
      before { sign_in user }

      it "creates an unclaimed image owned by the uploader" do
        expect do
          post :create, format: :json, params: { file: file }
        end.to change( PostImage, :count ).by( 1 )
        expect( response ).to have_http_status :created
        post_image = PostImage.last
        expect( post_image.user ).to eq user
        expect( post_image.post_id ).to be_nil
      end

      it "returns the image's id, absolute URLs and dimensions" do
        post :create, format: :json, params: { file: file }
        json = JSON.parse( response.body )
        expect( json.keys ).to include(
          "id", "original_url", "large_url", "medium_url", "small_url", "width", "height"
        )
        expect( json["id"] ).to eq PostImage.last.id
        %w(original_url large_url medium_url small_url).each do | key |
          expect( json[key] ).to match %r{\Ahttps?://.+/post_images/#{json['id']}/}
        end
      end

      it "ignores a post_id or user_id in the params" do
        other_post = Post.make!( parent: Site.make! )
        post :create, format: :json, params: { file: file, post_id: other_post.id, user_id: User.make!.id }
        expect( PostImage.last.post_id ).to be_nil
        expect( PostImage.last.user ).to eq user
      end

      it "rejects a file that is not an image" do
        expect do
          post :create, format: :json, params: {
            file: fixture_file_upload( "not-an-image.jpg", "image/jpeg" )
          }
        end.not_to change( PostImage, :count )
        expect( response ).to have_http_status :unprocessable_entity
        expect( JSON.parse( response.body )["errors"] ).not_to be_blank
      end

      it "rejects a request without a file" do
        expect do
          post :create, format: :json
        end.not_to change( PostImage, :count )
        expect( response ).to have_http_status :unprocessable_entity
      end

      it "rejects a file over 20 MB" do
        allow_any_instance_of( PostImage ).to receive( :file_file_size ).and_return( 21.megabytes )
        expect do
          post :create, format: :json, params: { file: file }
        end.not_to change( PostImage, :count )
        expect( response ).to have_http_status :unprocessable_entity
      end

      it "rejects uploads past the hourly limit" do
        stub_const( "PostImagesController::MAX_PER_HOUR", 1 )
        PostImage.make!( user: user )
        expect do
          post :create, format: :json, params: { file: file }
        end.not_to change( PostImage, :count )
        expect( response ).to have_http_status :too_many_requests
        expect( JSON.parse( response.body )["errors"] ).to eq [I18n.t( :post_image_upload_limit_reached )]
      end

      it "doesn't count uploads older than an hour or by other users toward the limit" do
        stub_const( "PostImagesController::MAX_PER_HOUR", 1 )
        PostImage.make!( user: user, created_at: 61.minutes.ago )
        PostImage.make!( user: User.make! )
        post :create, format: :json, params: { file: file }
        expect( response ).to have_http_status :created
      end
    end
  end

  describe "update" do
    let( :post_image ) { PostImage.make!( user: user ) }
    let( :metadata ) { { caption: "A <em>heron</em>", attribution: "Photo © someone", alt: "A heron" } }

    it "requires a logged-in user" do
      patch :update, format: :json, params: { id: post_image.id, post_image: metadata }
      expect( response ).to have_http_status :unauthorized
      expect( post_image.reload.alt ).to be_nil
    end

    it "lets the uploader set caption, attribution and alt" do
      sign_in user
      patch :update, format: :json, params: { id: post_image.id, post_image: metadata }
      expect( response ).to have_http_status :ok
      post_image.reload
      expect( post_image.caption ).to eq metadata[:caption]
      expect( post_image.attribution ).to eq metadata[:attribution]
      expect( post_image.alt ).to eq metadata[:alt]
      expect( JSON.parse( response.body )["alt"] ).to eq metadata[:alt]
    end

    it "ignores attributes other than caption, attribution and alt" do
      sign_in user
      other_post = Post.make!( parent: Site.make! )
      patch :update, format: :json, params: {
        id: post_image.id,
        post_image: metadata.merge( post_id: other_post.id, user_id: User.make!.id, width: 1 )
      }
      post_image.reload
      expect( post_image.post_id ).to be_nil
      expect( post_image.user ).to eq user
      expect( post_image.width ).not_to eq 1
    end

    it "is forbidden to other users" do
      sign_in User.make!
      patch :update, format: :json, params: { id: post_image.id, post_image: metadata }
      expect( response ).to have_http_status :forbidden
      expect( post_image.reload.alt ).to be_nil
    end

    it "is forbidden to admins who didn't upload the image" do
      sign_in make_admin
      patch :update, format: :json, params: { id: post_image.id, post_image: metadata }
      expect( response ).to have_http_status :forbidden
    end

    it "returns 404 for an unknown image" do
      sign_in user
      patch :update, format: :json, params: { id: 0, post_image: metadata }
      expect( response ).to have_http_status :not_found
    end

    it "won't clear the alt text of a published post's cover" do
      sign_in user
      post_record = Post.make!( :draft, parent: Site.make!, user: user )
      post_image.update!( post: post_record, alt: "A heron" )
      post_record.update!( cover_image: post_image, published_at: Time.now )
      patch :update, format: :json, params: { id: post_image.id, post_image: { alt: "" } }
      expect( response ).to have_http_status :unprocessable_entity
      expect( post_image.reload.alt ).to eq "A heron"
    end
  end
end
