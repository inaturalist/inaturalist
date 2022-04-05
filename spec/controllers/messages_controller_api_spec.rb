# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

shared_examples_for "a basic MessagesController" do
  let( :user ) { make_user_with_privilege( UserPrivilege::SPEECH ) }
  let( :to_user ) { make_user_with_privilege( UserPrivilege::SPEECH ) }

  it "should read a message" do
    message = make_message( user: user )
    get :show, format: :json, params: { id: message.id }
    json = JSON.parse( response.body )
    expect( json["results"].detect {| m | m["id"] == message.id } ).not_to be_blank
  end
end

shared_examples_for "a MessagesController" do
  let( :user ) { make_user_with_privilege( UserPrivilege::SPEECH ) }
  let( :to_user ) { make_user_with_privilege( UserPrivilege::SPEECH ) }

  describe "create" do
    def post_message
      post :create, format: :json, params: { message: {
        to_user_id: to_user.id,
        body: Faker::Lorem.paragraph
      } }
      JSON.parse( response.body )
    end
    it "should create a message" do
      expect { post_message }.to change( Message, :count ).by 2
    end
    it "should return just the message just created" do
      expect( post_message["id"] ).not_to be_blank
    end
    it "should make a copy for the recipient" do
      json = post_message
      expect(
        Message.where(
          thread_id: json["thread_id"],
          from_user_id: user.id,
          to_user_id: to_user.id
        ).first
      ).not_to be_blank
    end
    it "should not make a copy for the recipient if the recipient has blocked the sender" do
      UserBlock.make!( user: to_user, blocked_user: user )
      json = post_message
      expect(
        Message.where(
          thread_id: json["thread_id"],
          from_user_id: user.id,
          to_user_id: to_user.id
        ).first
      ).to be_blank
    end
    it "should return a 422 for a 0 user" do
      messages_count = Message.count
      post :create, format: :json, params: { message: {
        to_user_id: 0,
        subject: "foo",
        body: "bar"
      } }
      expect( Message.count ).to eq messages_count
      expect( response.response_code ).to eq 422
    end
  end

  describe "show" do
    it "should not allow you to view messages for other people" do
      message = make_message
      get :show, format: :json, params: { id: message.id }
      expect( response.code ).not_to eq 200
      json = JSON.parse( response.body )
      expect( json["error"] ).not_to be_blank
    end
    it "should include all messages in a thread" do
      message1 = make_message( user: user, from_user: user, to_user: to_user )
      message1.send_message
      message2 = make_message(
        thread_id: message1.thread_id,
        user: to_user,
        from_user: to_user,
        to_user: user
      )
      message2.send_message
      get :show, format: :json, params: { id: message1.id }
      json = JSON.parse( response.body )
      expect( json["results"].size ).to eq 2
    end
    it "should mark all messages in the thread as read" do
      message1 = make_message( user: user, from_user: user, to_user: to_user )
      message1.send_message
      message2 = make_message(
        thread_id: message1.thread_id,
        user: to_user,
        from_user: to_user,
        to_user: user
      )
      message2.send_message
      get :show, format: :json, params: { id: message1.id }
      expect(
        Message.inbox.where(
          user_id: user,
          thread_id: message1.thread_id
        ).where( "read_at IS NULL" ).first
      ).to be_blank
    end
  end

  describe "destroy" do
    it "should delete a message" do
      message = make_message( user: user, from_user: user, to_user: to_user )
      delete :destroy, format: :json, params: { id: message.id }
      expect( Message.find_by_id( message.id ) ).to be_blank
    end
    it "should not have a JSON response" do
      message = make_message( user: user, from_user: user, to_user: to_user )
      delete :destroy, format: :json, params: { id: message.id }
      expect( response.code ).to eq "204"
      expect( response.body ).to be_blank
    end
    it "should not destroy the recipient's copy" do
      message = make_message( user: user, from_user: user, to_user: to_user )
      message.send_message
      delete :destroy, format: :json, params: { id: message.id }
      expect( Message.where( thread_id: message.thread_id, user_id: to_user ).count ).to eq 1
    end
  end

  describe "index" do
    it "should show messages" do
      message = make_message( user: to_user, from_user: to_user, to_user: user )
      message.send_message
      get :index, format: :json
      json = JSON.parse( response.body )
      expect( json["results"].detect {| m | m["thread_id"] == message.thread_id } ).not_to be_blank
    end
    it "should show sent messages" do
      message = make_message( user: user, from_user: user, to_user: to_user )
      message.send_message
      get :index, format: :json, params: { box: "sent" }
      json = JSON.parse( response.body )
      expect( json["results"].detect {| m | m["id"] == message.id } ).not_to be_blank
    end
    it "should search messages by subject" do
      subject = "great grievous greaves"
      message = make_message( user: user, from_user: to_user, to_user: user, subject: subject )
      get :index, format: :json, params: { q: "greaves" }
      json = JSON.parse( response.body )
      expect( json["results"].detect {| m | m["id"] == message.id } ).not_to be_blank
    end
    it "should search messages by body" do
      body = "great grievous greaves"
      message = make_message( user: user, from_user: to_user, to_user: user, body: body )
      get :index, format: :json, params: { q: "greaves" }
      json = JSON.parse( response.body )
      expect( json["results"].detect {| m | m["id"] == message.id } ).not_to be_blank
    end
    it "should search messages by sender login" do
      login = "arcturus"
      to_user.update( login: login )
      message = make_message( user: user, from_user: to_user, to_user: user )
      get :index, format: :json, params: { q: login }
      json = JSON.parse( response.body )
      expect( json["results"].detect {| m | m["id"] == message.id } ).not_to be_blank
    end
    it "should search messages by sender name" do
      name = "arcturus"
      to_user.update( name: name )
      message = make_message( user: user, from_user: to_user, to_user: user )
      get :index, format: :json, params: { q: name }
      json = JSON.parse( response.body )
      expect( json["results"].detect {| m | m["id"] == message.id } ).not_to be_blank
    end
    describe "box=any and search" do
      it "should include inbox messages" do
        message = make_message( user: to_user, from_user: to_user, to_user: user, body: "is this ceanothus?" )
        message.send_message
        get :index, format: :json, params: { box: "any", q: "ceanothus" }
        json = JSON.parse( response.body )
        expect( json["results"].detect {| m | m["thread_id"] == message.thread_id } ).not_to be_blank
      end
      it "should include sent messages" do
        message = make_message( user: user, from_user: user, to_user: to_user, body: "is this ceanothus?" )
        message.send_message
        get :index, format: :json, params: { box: "any", q: "ceanothus" }
        json = JSON.parse( response.body )
        expect( json["results"].detect {| m | m["id"] == message.id } ).not_to be_blank
      end
    end
    describe "threads" do
      before do
        @m1 = make_message( user: user, from_user: user, to_user: to_user )
        @m1.send_message
        @m2 = make_message( user: to_user, from_user: to_user, to_user: user, thread_id: @m1.id )
        @m2.send_message
        @m3 = make_message( user: user, from_user: user, to_user: to_user, thread_id: @m1.id, body: "last reply" )
        @m3.send_message
        get :index, format: :json, params: { box: "any", threads: true }
        json = JSON.parse( response.body )
        @thread_results = json["results"].select {| m | m["thread_id"] == @m1.thread_id }
      end
      it "should include only one message per thread" do
        expect( @thread_results.size ).to eq 1
      end
      it "should the latest message in a thread" do
        expect( @thread_results[0]["body"] ).to eq @m3.body
      end
      it "should include a thread_messages_count attribute" do
        expect( @thread_results[0]["thread_messages_count"] ).to eq 3
      end
      it "should include a thread_flags array that includes flags on all messages" do
        expect( @m1.thread_id ).to eq @m3.thread_id
        m1_flag = Flag.make!( flaggable: @m1.to_user_copy, user: user )
        m2_flag = Flag.make!( flaggable: @m2, user: user )
        get :index, format: :json, params: { box: "any", threads: true }
        json = JSON.parse( response.body )
        thread_results = json["results"].select {| m | m["thread_id"] == @m1.thread_id }
        expect( thread_results[0]["thread_flags"].size ).to eq 2
        expect( thread_results[0]["thread_flags"].detect {| f | f["id"] == m1_flag.id } ).not_to be_blank
        expect( thread_results[0]["thread_flags"].detect {| f | f["id"] == m2_flag.id } ).not_to be_blank
      end
    end
  end

  describe "count" do
    it "should show the count of new messages" do
      message = make_message( user: to_user, from_user: to_user, to_user: user )
      message.send_message
      get :count, format: :json
      json = JSON.parse( response.body )
      expect( json["count"] ).to eq 1
    end
    it "should not count messages from a muted user" do
      UserMute.make!( user: user, muted_user: to_user )
      message = make_message( user: to_user, from_user: to_user, to_user: user )
      message.send_message
      get :count, format: :json
      json = JSON.parse( response.body )
      expect( json["count"] ).to eq 0
    end
  end
end

describe MessagesController, "oauth authentication" do
  let( :token ) do
    double acceptable?: true, accessible?: true, resource_owner_id: user.id, application: OauthApplication.make!
  end
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow( controller ).to receive( :doorkeeper_token ) { token }
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it_behaves_like "a basic MessagesController"
  it_behaves_like "a MessagesController"
end

describe MessagesController, "with authentication" do
  before { sign_in( user ) }
  it_behaves_like "a basic MessagesController"
end
