# frozen_string_literal: true

require "spec_helper"

describe BlogCategoriesController do
  let( :site ) { Site.make! }
  let( :other_site ) { Site.make! }
  let( :site_admin ) { SiteAdmin.make!( site: site ).user }

  describe "as a site admin" do
    render_views
    before { sign_in site_admin }

    it "lists only the current site's categories in position order" do
      second = BlogCategory.make!( site: site, position: 2 )
      first = BlogCategory.make!( site: site, position: 1 )
      BlogCategory.make!( site: other_site )
      get :index, params: { inat_site_id: site.id }
      expect( response ).to be_successful
      expect( assigns( :blog_categories ).to_a ).to eq [first, second]
    end

    it "lists categories without a position last" do
      unpositioned = BlogCategory.make!( site: site, position: nil )
      positioned = BlogCategory.make!( site: site, position: 5 )
      get :index, params: { inat_site_id: site.id }
      expect( assigns( :blog_categories ).to_a ).to eq [positioned, unpositioned]
    end

    it "links edit and delete by id rather than slug" do
      category = BlogCategory.make!( site: site, label: "Field Notes" )
      get :index, params: { inat_site_id: site.id }
      page = Nokogiri::HTML( response.body )
      expect( page.at_css( "a[href='#{edit_blog_category_path( id: category.id )}']" ) ).not_to be_nil
      expect( page.at_css( "a[data-method='delete'][href='#{blog_category_path( id: category.id )}']" ) ).not_to be_nil
      expect( response.body ).not_to include "/blog/categories/field-notes"
    end

    it "posts the edit form to the id URL" do
      category = BlogCategory.make!( site: site, label: "Field Notes" )
      get :edit, params: { inat_site_id: site.id, id: category.id }
      form = Nokogiri::HTML( response.body ).at_css( "form#edit_blog_category_#{category.id}" )
      expect( form["action"] ).to eq blog_category_path( id: category.id )
    end

    it "includes post counts on the index" do
      category = BlogCategory.make!( site: site )
      2.times { Post.make!( parent: site, user: site_admin, blog_category: category ) }
      get :index, params: { inat_site_id: site.id }
      expect( assigns( :blog_categories ).first.posts_count ).to eq 2
    end

    it "renders the new and edit forms" do
      category = BlogCategory.make!( site: site )
      get :new, params: { inat_site_id: site.id }
      expect( response ).to be_successful
      get :edit, params: { inat_site_id: site.id, id: category.id }
      expect( response.body ).to include category.label
    end

    it "creates a category on the current site with a slug from the label" do
      expect do
        post :create, params: { inat_site_id: site.id, blog_category: { label: "Field Notes", position: 3 } }
      end.to change( site.blog_categories, :count ).by( 1 )
      category = site.blog_categories.last
      expect( category.slug ).to eq "field-notes"
      expect( category.position ).to eq 3
      expect( response ).to redirect_to blog_categories_path
    end

    it "ignores a submitted slug or site" do
      post :create, params: {
        inat_site_id: site.id,
        blog_category: { label: "Field Notes", slug: "custom", site_id: other_site.id }
      }
      category = BlogCategory.last
      expect( category.slug ).to eq "field-notes"
      expect( category.site ).to eq site
    end

    it "refuses a label that would make the slug all" do
      expect do
        post :create, params: { inat_site_id: site.id, blog_category: { label: "All" } }
      end.not_to change( BlogCategory, :count )
      expect( response ).to render_template :new
      expect( assigns( :blog_category ).errors.full_messages ).to include "Label is reserved"
    end

    it "re-renders the form when the position is too large" do
      expect do
        post :create, params: { inat_site_id: site.id, blog_category: { label: "Field Notes", position: 99_999_999_999 } }
      end.not_to change( BlogCategory, :count )
      expect( response ).to have_http_status :unprocessable_entity
      expect( response ).to render_template :new
    end

    it "re-renders the form when the label is already used on the site" do
      BlogCategory.make!( site: site, label: "Field Notes" )
      expect do
        post :create, params: { inat_site_id: site.id, blog_category: { label: "field notes" } }
      end.not_to change( BlogCategory, :count )
      expect( response ).to render_template :new
    end

    it "refuses a blank label" do
      expect do
        post :create, params: { inat_site_id: site.id, blog_category: { label: "" } }
      end.not_to change( BlogCategory, :count )
      expect( response ).to render_template :new
      expect( assigns( :blog_category ).errors[:label] ).not_to be_empty
    end

    it "refuses renaming to a label that would make the slug all" do
      category = BlogCategory.make!( site: site, label: "Keep" )
      put :update, params: { inat_site_id: site.id, id: category.id, blog_category: { label: "All" } }
      expect( response ).to render_template :edit
      expect( assigns( :blog_category ).errors ).not_to be_empty
      expect( category.reload.label ).to eq "Keep"
      expect( category.slug ).to eq "keep"
    end

    it "updates the label and the slug follows, keeping the old slug resolvable" do
      category = BlogCategory.make!( site: site, label: "Old Name" )
      put :update, params: { inat_site_id: site.id, id: category.id, blog_category: { label: "New Name" } }
      category.reload
      expect( category.label ).to eq "New Name"
      expect( category.slug ).to eq "new-name"
      expect( site.blog_categories.friendly.find( "old-name" ) ).to eq category
      expect( response ).to redirect_to blog_categories_path
    end

    it "deletes an unused category" do
      category = BlogCategory.make!( site: site )
      delete :destroy, params: { inat_site_id: site.id, id: category.id }
      expect( BlogCategory.exists?( category.id ) ).to be false
      expect( response ).to redirect_to blog_categories_path
    end

    it "refuses to delete a category with posts and reports the post count" do
      category = BlogCategory.make!( site: site )
      2.times { Post.make!( parent: site, user: site_admin, blog_category: category ) }
      delete :destroy, params: { inat_site_id: site.id, id: category.id }
      expect( BlogCategory.exists?( category.id ) ).to be true
      expect( flash[:error] ).to include "2"
    end

    it "can't reach another site's category by id" do
      foreign = BlogCategory.make!( site: other_site, label: "Foreign" )
      get :edit, params: { inat_site_id: site.id, id: foreign.id }
      expect( response.status ).to eq 404
      put :update, params: { inat_site_id: site.id, id: foreign.id, blog_category: { label: "Hijacked" } }
      expect( foreign.reload.label ).to eq "Foreign"
      delete :destroy, params: { inat_site_id: site.id, id: foreign.id }
      expect( BlogCategory.exists?( foreign.id ) ).to be true
    end
  end

  shared_examples_for "refused" do | redirect_path |
    let!( :category ) { BlogCategory.make!( site: site, label: "Keep" ) }

    def attempt( &block )
      catch( :abort, &block )
    end

    it "refuses index" do
      attempt { get :index, params: { inat_site_id: site.id } }
      expect( response ).to redirect_to send( redirect_path )
      expect( assigns( :blog_categories ) ).to be_nil
    end

    it "refuses create" do
      expect do
        attempt { post :create, params: { inat_site_id: site.id, blog_category: { label: "Nope" } } }
      end.not_to change( BlogCategory, :count )
      expect( response ).to redirect_to send( redirect_path )
    end

    it "refuses update" do
      attempt { put :update, params: { inat_site_id: site.id, id: category.id, blog_category: { label: "Changed" } } }
      expect( category.reload.label ).to eq "Keep"
      expect( response ).to redirect_to send( redirect_path )
    end

    it "refuses destroy" do
      attempt { delete :destroy, params: { inat_site_id: site.id, id: category.id } }
      expect( BlogCategory.exists?( category.id ) ).to be true
      expect( response ).to redirect_to send( redirect_path )
    end
  end

  shared_examples_for "refused with an admin-only error" do
    it "says only administrators may access the page" do
      catch( :abort ) { get :index, params: { inat_site_id: site.id } }
      expect( flash[:error] ).to eq I18n.t( :only_administrators_may_access_that_page )
    end
  end

  describe "logged out" do
    it_behaves_like "refused", :new_user_session_path
  end

  describe "as a normal user" do
    before { sign_in User.make! }
    it_behaves_like "refused", :observations_path
    it_behaves_like "refused with an admin-only error"
  end

  describe "as an admin of another site" do
    before { sign_in SiteAdmin.make!( site: other_site ).user }
    it_behaves_like "refused", :observations_path
    it_behaves_like "refused with an admin-only error"
  end
end
