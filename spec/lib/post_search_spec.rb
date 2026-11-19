# frozen_string_literal: true

require "spec_helper"

describe PostSearch do
  # TODO: Post has no lifecycle callbacks until WEB-1426
  before { enable_elastic_indexing( Post, use_transactional_fixtures: false ) }

  def index!( *posts )
    Post.elastic_index!( ids: posts.flatten.map( &:id ) )
  end

  def search_ids( params = {} )
    PostSearch.new( params ).results.map( &:id )
  end

  def journal_post( attrs = {} )
    author = attrs[:user] || User.make!
    Post.make!( { user: author, parent: author, title: "Weekly notes", body: "Nothing to see here" }.merge( attrs ) )
  end

  describe "query_body" do
    it "wraps the match in a recency function_score when q is present" do
      body = PostSearch.new( q: "pangolin" ).query_body
      function_score = body[:query][:function_score]
      expect( function_score ).not_to be_nil
      expect( function_score[:boost_mode] ).to eq "multiply"
      expect( function_score[:score_mode] ).to eq "sum"
      expect( function_score[:functions] ).to include( { weight: 1 } )
      expect( function_score[:functions] ).to include(
        { gauss: { published_at: PostSearch::RECENCY_BOOST } }
      )
    end

    it "does not score or boost without q" do
      body = PostSearch.new( {} ).query_body
      expect( body[:query].to_s ).not_to include "function_score"
      expect( body[:sort].first ).to eq( { published_at: "desc" } )
    end

    it "sorts by date when an explicit date order is given with q" do
      body = PostSearch.new( q: "pangolin", order: "oldest" ).query_body
      expect( body[:sort].first ).to eq( { published_at: "asc" } )
    end

    it "caps per_page" do
      expect( PostSearch.new( per_page: 10_000 ).query_body[:size] ).to eq PostSearch::MAX_PER_PAGE
    end
  end

  describe "relevance" do
    it "ranks a title match above a body-only match" do
      body_match = journal_post( title: "Weekly notes", body: "Today we saw a pangolin by the road" )
      title_match = journal_post( title: "Pangolin sightings", body: "Lots of walking today" )
      index!( body_match, title_match )
      expect( search_ids( q: "pangolin" ) ).to eq [title_match.id, body_match.id]
    end

    it "still matches with a one-letter typo" do
      post = journal_post( title: "Pangolin sightings" )
      index!( post )
      expect( search_ids( q: "pangolon" ) ).to eq [post.id]
    end

    it "matches the author's login and real name" do
      author = User.make!( login: "quokkawatcher", name: "Florentyna Bramblewick" )
      post = journal_post( user: author, parent: author )
      index!( post, journal_post )
      expect( search_ids( q: "quokkawatcher" ) ).to eq [post.id]
      expect( search_ids( q: "Bramblewick" ) ).to eq [post.id]
    end

    it "matches tags" do
      post = journal_post( tag_list: ["nudibranch"] )
      index!( post, journal_post )
      expect( search_ids( q: "nudibranch" ) ).to eq [post.id]
    end

    it "matches words the English stopword list would drop" do
      post = journal_post( title: "No hay ranas" )
      index!( post, journal_post )
      expect( search_ids( q: "no" ) ).to eq [post.id]
    end
  end

  describe "recency" do
    it "ranks the recent post first when matches are similarly good" do
      old = journal_post( title: "Quokka census", published_at: 3.years.ago )
      recent = journal_post( title: "Quokka census report", published_at: 5.days.ago )
      index!( old, recent )
      expect( search_ids( q: "quokka census" ) ).to eq [recent.id, old.id]
    end

    it "still ranks a much better old match first" do
      old = journal_post(
        title: "Quokka census",
        body: "The quokka census counted every quokka",
        published_at: 3.years.ago
      )
      recent = journal_post(
        title: "Weekly notes",
        body: "We walked for a long time along the coast, looked at birds and plants, " \
          "talked about the weather, had lunch, and on the way back a quokka census volunteer waved",
        published_at: 5.days.ago
      )
      index!( old, recent )
      expect( search_ids( q: "quokka census" ) ).to eq [old.id, recent.id]
    end
  end

  describe "default exclusions" do
    it "excludes drafts, spam and posts by spammers" do
      visible = journal_post( title: "Axolotl" )
      draft = journal_post( title: "Axolotl", published_at: nil )
      spam = journal_post( title: "Axolotl" )
      Flag.make!( flaggable: spam, flag: Flag::SPAM )
      spammer_post = journal_post( title: "Axolotl" )
      spammer_post.user.update_column( :spammer, true )
      index!( visible, draft, spam, spammer_post )
      expect( search_ids( q: "axolotl" ) ).to eq [visible.id]
      expect( search_ids ).to eq [visible.id]
    end
  end

  describe "filters" do
    let( :project ) { Project.make! }
    let( :site ) { Site.make! }
    let( :site_post ) { Post.make!( parent: site, user: User.make!, title: "Axolotl news" ) }
    let( :project_post ) { Post.make!( parent: project, user: project.user, title: "Axolotl survey" ) }
    let( :user_post ) { journal_post( title: "Axolotl diary" ) }

    before { index!( site_post, project_post, user_post ) }

    it "scopes by parent" do
      expect( search_ids( q: "axolotl", parent_type: "Project", parent_id: project.id ) ).to eq [project_post.id]
      expect( search_ids( parent_type: "Site", parent_id: site.id ) ).to eq [site_post.id]
      expect( search_ids( q: "axolotl", parent_type: "User", parent_id: user_post.parent_id ) ).to eq [user_post.id]
    end

    it "scopes by user" do
      expect( search_ids( q: "axolotl", user_id: project.user_id ) ).to eq [project_post.id]
    end

    it "scopes by site" do
      expect( search_ids( site_id: site.id ) ).to eq [site_post.id]
    end

    it "requires every tag" do
      both = journal_post( tag_list: ["Fungi", "Lichen"] )
      one = journal_post( tag_list: ["fungi"] )
      index!( both, one )
      expect( search_ids( tags: "fungi" ) ).to contain_exactly( both.id, one.id )
      expect( search_ids( tags: ["fungi", "LICHEN"] ) ).to eq [both.id]
    end
  end

  describe "results" do
    it "orders by published_at without q" do
      older = journal_post( published_at: 2.days.ago )
      newer = journal_post( published_at: 1.day.ago )
      index!( older, newer )
      expect( search_ids ).to eq [newer.id, older.id]
      expect( search_ids( order: "oldest" ) ).to eq [older.id, newer.id]
    end

    it "paginates with correct totals" do
      posts = Array.new( 3 ) {| i | journal_post( published_at: i.days.ago ) }
      index!( posts )
      results = PostSearch.new( page: 2, per_page: 2 ).results
      expect( results.total_entries ).to eq 3
      expect( results.map( &:id ) ).to eq [posts.last.id]
    end

    it "loads records with the posts_json preloads" do
      index!( journal_post )
      post = PostSearch.new( {} ).results.first
      expect( post.association( :user ) ).to be_loaded
      expect( post.association( :parent ) ).to be_loaded
    end

    it "drops ids that are no longer in the database" do
      gone = journal_post
      index!( gone )
      Post.where( id: gone.id ).delete_all
      expect( search_ids ).to eq []
    end

    it "does not return trips" do
      trip = Trip.make!( title: "Axolotl trip" )
      index!( trip )
      expect( search_ids( q: "axolotl" ) ).to eq []
    end

    it "returns escaped highlights for title and body" do
      post = journal_post( title: "Pangolin <3", body: "<p>A pangolin crossed the road.</p>" )
      index!( post )
      search = PostSearch.new( q: "pangolin" )
      search.results
      expect( search.highlights[post.id]["title"].first ).to eq "<em>Pangolin</em> &lt;3"
      expect( search.highlights[post.id]["body"].first ).to include "A <em>pangolin</em> crossed the road."
    end
  end
end
