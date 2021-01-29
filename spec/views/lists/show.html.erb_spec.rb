require "spec_helper"

describe "lists/show" do
  it "includes the user name in link to dynamic life list title if not there already" do
    u = User.make!
    I18n.locale = "en"
    render
    expect(rendered).to match /#{ u.login }'s Life List/
  end
end
