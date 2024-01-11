# frozen_string_literal: true

require "spec_helper"

describe "Paperclip" do
  let( :user ) do
    user = User.make!
    File.open( "#{File.dirname( __FILE__ )}/../fixtures/files/egg.jpg" ) do | f |
      user.update( icon: f )
    end
    user
  end

  it "interpolates :root_url" do
    expect(
      Paperclip::Interpolations.interpolate( "/:root_url", user.icon, :medium )
    ).to eq "/#{UrlHelper.root_url.chomp( '/' )}"
  end

  it "interpolates :icon_type_extension" do
    expect(
      Paperclip::Interpolations.interpolate( "/:icon_type_extension", user.icon, :medium )
    ).to eq "/jpg"
  end

  it "interpolates any column" do
    locale = "thelocale"
    user.update( locale: locale )
    expect(
      Paperclip::Interpolations.interpolate( "/:locale", user.icon )
    ).to eq "/#{user.locale}"

    login = "thelogin"
    user.update( login: login )
    expect(
      Paperclip::Interpolations.interpolate( "/:login", user.icon )
    ).to eq "/#{user.login}"
  end

  it "interpolates any method" do
    method_return = "somevalue"
    expect( user ).to receive( :some_method ).and_return( method_return )
    expect(
      Paperclip::Interpolations.interpolate( "/:some_method", user.icon )
    ).to eq "/#{method_return}"
  end

  it "interpolates any number of patterns" do
    method_a_return = "method_a_return"
    expect( user ).to receive( :method_a ).and_return( method_a_return )
    method_b_return = "method_b_return"
    expect( user ).to receive( :method_b ).and_return( method_b_return )
    method_c_return = "method_c_return"
    expect( user ).to receive( :method_c ).and_return( method_c_return )
    expect(
      Paperclip::Interpolations.interpolate( "/:method_a-:method_b/:method_c.:icon_type_extension", user.icon, :medium )
    ).to eq "/#{method_a_return}-#{method_b_return}/#{method_c_return}.jpg"
  end
end
