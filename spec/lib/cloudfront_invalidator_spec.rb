require "spec_helper"

describe CloudfrontInvalidator do

  before :all do
    class User < ApplicationRecord
      invalidate_cloudfront_caches :icon, "attachments/users/icons/:id/*"
    end
  end

  it "does not invalidate when adding attachments for the first time" do
    expect( INatAWS ).to_not receive(:cloudfront_invalidate)
    u = User.make!
    u.icon.assign(File.new(File.join(Rails.root, "app/assets/images/404mole.png")))
    without_delay { u.save }
  end

  it "invalidates when updating attachments" do
    u = User.make!(icon_file_name: "something", icon_content_type: "jpg", icon_updated_at: Time.now)
    expect( INatAWS ).to receive(:cloudfront_invalidate).with("attachments/users/icons/#{u.id}/*")
    u.icon.assign(File.new(File.join(Rails.root, "app/assets/images/404mole.png")))
    without_delay { u.save }
  end

  it "invalidates when removing attachments" do
    u = User.make!(icon_file_name: "something", icon_content_type: "jpg", icon_updated_at: Time.now)
    expect( INatAWS ).to receive(:cloudfront_invalidate).with("attachments/users/icons/#{u.id}/*")
    u.icon = nil
    without_delay { u.save }
  end

  it "does not invalidate when not changing attachments" do
    u = User.make!
    u.icon.assign(File.new(File.join(Rails.root, "app/assets/images/404mole.png")))
    without_delay { u.save }
    expect( INatAWS ).to_not receive(:cloudfront_invalidate).with("attachments/users/icons/#{u.id}/*")
    without_delay { u.save }
  end

end
