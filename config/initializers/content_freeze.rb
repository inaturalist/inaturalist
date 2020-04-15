module ContentFreeze

  extend ActiveSupport::Concern

  included do
    validate :content_freeze_not_enabled

    def content_freeze_not_enabled
      if CONFIG.content_freeze_enabled
        errors.add( :base, "cannot be changed during a content freeze" )
      end
    end

  end
end
