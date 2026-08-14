# frozen_string_literal: true

require "spec_helper"

# Exercises the curated list in config.active_support.disallowed_deprecation_warnings
# (config/application.rb). The test environment raises on these
# (config/environments/test.rb) so CI fails on upgrade-breaking usage, while other
# environments log them. Messages here mirror the real Rails wording so the specs
# lock the pattern-to-message contract for each list entry.
describe "disallowed deprecation warnings" do
  it "raises on require_dependency deprecations" do
    expect do
      ActiveSupport::Deprecation.warn(
        "require_dependency is deprecated and will be removed in Rails 7.1"
      )
    end.to raise_error( ActiveSupport::DeprecationException )
  end

  it "raises on positional serialize coder deprecations" do
    expect do
      ActiveSupport::Deprecation.warn(
        "Passing the coder as positional argument is deprecated and will be " \
          "removed in Rails 7.2. Please pass the coder as a keyword argument."
      )
    end.to raise_error( ActiveSupport::DeprecationException )
  end

  it "raises on keyword-argument enum deprecations" do
    expect do
      ActiveSupport::Deprecation.warn(
        "Defining enums with keyword arguments is deprecated and will be " \
          "removed in Rails 8.0. Positional arguments should be used instead."
      )
    end.to raise_error( ActiveSupport::DeprecationException )
  end

  it "raises on assets missing from the asset pipeline" do
    expect do
      ActiveSupport::Deprecation.warn(
        "The asset \"admin/user_content.css\" is not present in the asset pipeline.\n" \
          "Falling back to an asset that may be in the public folder.\n" \
          "This behavior is deprecated and will be removed."
      )
    end.to raise_error( ActiveSupport::DeprecationException )
  end

  it "raises on rendering actions with '.' in the name" do
    expect do
      ActiveSupport::Deprecation.warn(
        "Rendering actions with '.' in the name is deprecated: guides/show_grid.pdf.haml"
      )
    end.to raise_error( ActiveSupport::DeprecationException )
  end

  it "subscribes to deprecation notifications for production logging" do
    expect(
      ActiveSupport::Notifications.notifier.listening?( "deprecation.rails" )
    ).to be true
  end

  it "does not raise on deprecations that are not on the disallowed list" do
    original_behavior = ActiveSupport::Deprecation.behavior
    begin
      # silence the default :stderr behavior to keep test output clean
      ActiveSupport::Deprecation.behavior = :silence
      expect do
        ActiveSupport::Deprecation.warn( "some other deprecation we tolerate for now" )
      end.not_to raise_error
    ensure
      ActiveSupport::Deprecation.behavior = original_behavior
    end
  end
end
