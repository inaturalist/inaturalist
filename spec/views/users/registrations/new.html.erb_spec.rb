require "spec_helper"

describe "users/registrations/new" do

  describe "recaptcha" do
    it "does not render recaptcha if the site is not configured" do
      @site = Site.make!
      render
      expect(rendered).to_not have_selector(".g-recaptcha")
    end

    it "renders recaptcha for sites with recaptcha configs" do
      @site = Site.make!(
        prefers_google_recaptcha_key: "recaptcha_key",
        prefers_google_recaptcha_secret: "recaptcha_secret")
      render
      expect(rendered).to have_selector(".g-recaptcha")
    end
  end

end
