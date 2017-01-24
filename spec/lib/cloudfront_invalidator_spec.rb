require "spec_helper"

describe CloudfrontInvalidator do

  before :all do
    class User < ActiveRecord::Base
      invalidate_cloudfront_caches :icon, "attachments/users/icons/:id/*"
    end
  end

  it "not invalidate when adding attachments for the first time" do
    expect( INatAWS ).to_not receive(:cloudfront_invalidate)
    u = User.make!
    u.icon.assign(File.new(File.join(Rails.root, "app/assets/images/404mole.png")))
    u.save
  end

  it "invalidates when updating attachments" do
    u = User.make!(icon_file_name: "something", icon_content_type: "jpg", icon_updated_at: Time.now)
    expect( INatAWS ).to receive(:cloudfront_invalidate).with("attachments/users/icons/#{u.id}/*")
    u.icon.assign(File.new(File.join(Rails.root, "app/assets/images/404mole.png")))
    u.save
  end

  it "invalidates when removing attachments" do
    u = User.make!(icon_file_name: "something", icon_content_type: "jpg", icon_updated_at: Time.now)
    expect( INatAWS ).to receive(:cloudfront_invalidate).with("attachments/users/icons/#{u.id}/*")
    u.icon = nil
    u.save
  end

end
