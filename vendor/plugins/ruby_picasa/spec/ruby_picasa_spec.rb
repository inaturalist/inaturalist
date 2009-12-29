require File.join(File.dirname(__FILE__), 'spec_helper')

class Picasa
  class << self
    public :parse_url
  end
  public :auth_header, :with_cache, :class_from_xml, :xml_data
end

describe 'Picasa class methods' do
  it 'should generate an authorization_url' do
    return_url = 'http://example.com/example?example=ex'
    url = Picasa.authorization_url(return_url)
    url.should include(CGI.escape(return_url))
    url.should match(/session=1/)
  end

  describe 'token_in_request?' do
    it 'should be nil if no token' do
      request = mock('request', :parameters => { })
      Picasa.token_in_request?(request).should be_nil
    end

    it 'should not be nil if there is a token' do
      request = mock('request', :parameters => { 'token' => 'abc' })
      Picasa.token_in_request?(request).should_not be_nil
    end
  end

  describe 'token_from_request' do
    it 'should pluck the token from the request' do
      request = mock('request', :parameters => { 'token' => 'abc' })
      Picasa.token_from_request(request).should == 'abc'
    end
    it 'should raise if no token is present' do
      request = mock('request', :parameters => { })
      lambda do
        Picasa.token_from_request(request)
      end.should raise_error(RubyPicasa::PicasaTokenError)
    end
  end

  it 'should authorize a request' do
    Picasa.expects(:token_from_request).with(:request).returns('abc')
    picasa = mock('picasa')
    Picasa.expects(:new).with('abc').returns(picasa)
    picasa.expects(:authorize_token!).with()
    Picasa.authorize_request(:request).should == picasa
  end

  it 'should recognize absolute urls' do
    Picasa.is_url?('http://something.com').should be_true
    Picasa.is_url?('https://something.com').should be_true
    Picasa.is_url?('12323412341').should_not be_true
  end

  it 'should allow host change' do
    Picasa.host = 'abc'
    Picasa.host.should == 'abc'
  end

  describe 'path' do
    it 'should use parse_url and add options' do
      Picasa.expects(:parse_url).with({}).returns(['url', {'a' => 'b'}])
      Picasa.path({}).should ==
        "url?a=b"
    end
    it 'should build the url from user_id and album_id and add options' do
      hash = { :user_id => '123', :album_id => '321' }
      Picasa.expects(:parse_url).with(hash).returns([nil, {}])
      Picasa.path(hash).should ==
        "/data/feed/api/user/123/albumid/321?kind=photo"
    end
    it 'should build the url from special user_id all' do
      hash = { :user_id => 'all' }
      Picasa.expects(:parse_url).with(hash).returns([nil, {}])
      Picasa.path(hash).should ==
        "/data/feed/api/all"
    end
    [ :max_results, :start_index, :tag, :q, :kind,
      :access, :bbox, :l].each do |arg|
      it "should add #{ arg } to options" do
        Picasa.path(:url => 'url', arg => '!value').should ==
          "url?#{ arg.to_s.dasherize }=%21value"
      end
    end
    [ :imgmax, :thumbsize ].each do |arg|
      it "should raise PicasaError with invalid #{ arg } option" do
        lambda do
          Picasa.path(:url => 'url', arg => 'invalid')
        end.should raise_error(RubyPicasa::PicasaError)
      end
    end
    [ :imgmax, :thumbsize ].each do |arg|
      it "should add #{ arg } to options" do
        Picasa.path(:url => 'url', arg => '72').should ==
          "url?#{ arg.to_s.dasherize }=72"
      end
    end
    it 'should ignore unknown options' do
      Picasa.path(:url => 'place', :eggs => 'over_easy').should == 'place'
    end
  end

  describe 'parse_url' do
    it 'should prefer url' do
      hash = { :url => 'url', :user_id => 'user_id', :album_id => 'album_id' }
      Picasa.parse_url(hash).should == ['url', {}]
    end
    it 'should next prefer user_id' do
      Picasa.stubs(:is_url?).returns true
      hash = { :user_id => 'user_id', :album_id => 'album_id' }
      Picasa.parse_url(hash).should == ['user_id', {}]
    end
    it 'should use album_id' do
      Picasa.stubs(:is_url?).returns true
      hash = { :album_id => 'album_id' }
      Picasa.parse_url(hash).should == ['album_id', {}]
    end
    it 'should split up the params' do
      hash = { :url => 'url?specs=fun%21' }
      Picasa.parse_url(hash).should == ['url', { 'specs' => 'fun!' }]
    end
    it 'should not use non-url user_id or album_id' do
      hash = { :user_id => 'user_id', :album_id => 'album_id' }
      Picasa.parse_url(hash).should == [nil, {}]
    end
    it 'should handle with no relevant options' do
      hash = { :saoetu => 'aeu' }
      Picasa.parse_url(hash).should == [nil, {}]
    end
  end
end

describe Picasa do
  def body(text)
    #open_file('user_feed.atom').read
    @response.stubs(:body).returns(text)
  end

  before do
    @response = mock('response')
    @response.stubs(:code).returns '200'
    @http = mock('http')
    @http.stubs(:get).returns @response
    Net::HTTP.stubs(:new).returns(@http)
    @p = Picasa.new 'token'
  end

  it 'should initialize' do
    @p.token.should == 'token'
  end

  describe 'authorize_token!' do
    before do
      @p.expects(:auth_header).returns('Authorization' => 'etc')
      @http.expects(:use_ssl=).with true
      @http.expects(:get).with('/accounts/accounts/AuthSubSessionToken', 
        'Authorization' => 'etc').returns(@response)
    end

    it 'should set the new token' do
      body 'Token=hello'
      @p.authorize_token!
      @p.token.should == 'hello'
    end

    it 'should raise if the token is not found' do
      body 'nothing to see here'
      lambda do
        @p.authorize_token!
      end.should raise_error(RubyPicasa::PicasaTokenError)
      @p.token.should == 'token'
    end
  end

  it 'should get the user' do
    @p.expects(:get).with(:user_id => nil)
    @p.user
  end

  it 'should get an album' do
    @p.expects(:get).with(:album_id => 'album')
    @p.album('album')
  end
  
  it 'should get a url' do
    @p.expects(:get).with(:url => 'the url')
    @p.get_url('the url')
  end

  describe 'search' do
    it 'should prefer given options' do
      @p.expects(:get).with(:q => 'q', :max_results => 20, :user_id => 'me', :kind => 'comments')
      @p.search('q', :max_results => 20, :user_id => 'me', :kind => 'comments', :q => 'wrong')
    end
    it 'should have good defaults' do
      @p.expects(:get).with(:q => 'q', :max_results => 10, :user_id => 'all', :kind => 'photo')
      @p.search('q')
    end
  end

  it 'should get recent photos' do
    @p.expects(:get).with(:recent_photos => true, :max_results => 10)
    @p.recent_photos :max_results => 10
  end

  describe 'album_by_title' do
    before do
      @a1 = mock('a1')
      @a2 = mock('a2')
      @a1.stubs(:title).returns('a1')
      @a2.stubs(:title).returns('a2')
      albums = [ @a1, @a2 ]
      user = mock('user', :albums => albums)
      @p.expects(:user).returns(user)
    end

    it 'should match the title string' do
      @a2.expects(:load).with({}).returns :result
      @p.album_by_title('a2').should == :result
    end

    it 'should match a regex' do
      @a1.expects(:load).with({}).returns :result
      @p.album_by_title(/a\d/).should == :result
    end

    it 'should return nil' do
      @p.album_by_title('zzz').should be_nil
    end
  end

  describe 'xml' do
    it 'should return the body with a 200 status' do
      body 'xml goes here'
      @p.xml.should == 'xml goes here'
    end
    it 'should return nil with a non-200 status' do
      body 'xml goes here'
      @response.expects(:code).returns '404'
      @p.xml.should be_nil
    end
  end

  describe 'get' do
    it 'should call class_from_xml if with_cache yields' do
      @p.expects(:with_cache).with({}).yields(:xml).returns(:result)
      @p.expects(:class_from_xml).with(:xml)
      @p.send(:get).should == :result
    end

    it 'should do nothing if with_cache does not yield' do
      @p.expects(:with_cache).with({}) # doesn't yield
      @p.expects(:class_from_xml).never
      @p.send(:get).should be_nil
    end
  end

  describe 'auth_header' do
    it 'should build an AuthSub header' do
      @p.auth_header.should == { "Authorization" => %{AuthSub token="token"} }
    end

    it 'should do nothing' do
      p = Picasa.new nil
      p.auth_header.should == { }
    end
  end

  describe 'with_cache' do
    it 'yields fresh xml' do
      body 'fresh xml'
      yielded = false
      @p.with_cache(:url => 'place') do |xml|
        yielded = true
        xml.should == 'fresh xml'
      end
      yielded.should be_true
    end

    it 'yields cached xml' do
      @p.instance_variable_get('@request_cache')['place'] = 'some xml'
      yielded = false
      @p.with_cache(:url => 'place') do |xml|
        yielded = true
        xml.should == 'some xml'
      end
      yielded.should be_true
    end
  end

  describe 'xml_data' do
    it 'should extract categories from the xml' do
      xml, feed_schema, entry_schema = @p.xml_data(open_file('album.atom'))
      xml.should be_an_instance_of(Nokogiri::XML::Element)
      feed_schema.should == 'http://schemas.google.com/photos/2007#album'
      entry_schema.should == 'http://schemas.google.com/photos/2007#photo'
    end

    it 'should handle nil' do
      xml, feed_schema, entry_schema = @p.xml_data(nil)
      xml.should be_nil
    end

    it 'should handle bad xml' do
      xml, feed_schema, entry_schema = @p.xml_data('<entry>something went wrong')
      xml.should_not be_nil
      feed_schema.should be_nil
      entry_schema.should be_nil
    end
  end

  describe 'class_from_xml' do
    before do
      @user = 'http://schemas.google.com/photos/2007#user'
      @album = 'http://schemas.google.com/photos/2007#album'
      @photo = 'http://schemas.google.com/photos/2007#photo'
    end

    describe 'valid feed category types' do
      def to_create(klass, feed, entry)
        @object = mock('object', :session= => nil)
        @p.expects(:xml_data).with(:xml).returns([:xml, feed, entry])
        klass.expects(:new).with(:xml, @p).returns(@object)
        @p.class_from_xml(:xml)
      end
      it('user album')  { to_create RubyPicasa::User, @user, @album }
      it('user photo')  { to_create RubyPicasa::RecentPhotos, @user, @photo }
      it('album nil')   { to_create RubyPicasa::Album, @album, nil }
      it('album photo') { to_create RubyPicasa::Album, @album, @photo }
      it('photo nil')   { to_create RubyPicasa::Photo, @photo, nil }
      it('photo photo') { to_create RubyPicasa::Search, @photo, @photo }
    end
    
    # I broke this test, though I'm not sure how to fix it (or why it ever 
    # worked to begin with).  Shouldn't it always break when you pass in a 
    # symbol instead of actual xml?  -- kueda 2009-12-29
    it 'should raise an error for invalid feed category types' do
      @p.expects(:xml_data).with(:xml).returns([:xml, @album, @user])
      lambda do
        @p.class_from_xml(:xml)
      end.should raise_error(RubyPicasa::PicasaError)
    end
  end
end
