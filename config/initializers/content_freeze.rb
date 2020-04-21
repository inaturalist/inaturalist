module ContentFreeze

  extend ActiveSupport::Concern

  included do
    validate :content_freeze_not_enabled

    def content_freeze_not_enabled
      if CONFIG.content_freeze_enabled
        errors.add( :base, I18n.t( "cannot_be_changed_during_a_content_freeze" ) )
      end
    end

  end
end
