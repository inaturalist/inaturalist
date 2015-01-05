module ActiveRecord
  class Base
    class << self

      def acts_as_spammable(options={})

        include Rakismet::Model

        rakismet_fields = options[:fields]
        # set up the rakismet attributes. Concatenate multiple
        # fields using periods as if sentences
        rakismet_attrs :author => proc { user.name },
                       :author_email => proc { user.email },
                       :content => proc {
                         options[:fields].map{ |f|
                           self.respond_to?(f) ? self.send(f) : nil
                         }.compact.join(". ")
                       },
                       :comment_type => options[:comment_type]

        after_save :check_for_spam
        scope :flagged_as_spam,
          joins(:flags).where({ flags: { flag: Flag::SPAM } })

        define_method(:flagged_as_spam?) do
          self.class.flagged_as_spam.exists?(self)
        end

        # If any of the rakismet fields has been modified, then
        # call the akismet API and update the flags on this object.
        # Flags are made with user_id = 0, representing automated flags
        define_method(:check_for_spam) do
          if Rakismet.disabled.nil?
            Rakismet.disabled = Rails.env.test?
          end
          unless Rakismet.disabled
            if (self.changed.map(&:to_sym) & rakismet_fields).any?
              if self.spam?
                self.add_flag( flag: "spam", user_id: 0 )
              elsif self.flagged_as_spam?
                Flag.delete_all(flaggable_id: self.id, flaggable_type: self.class,
                  user_id: 0, flag: Flag::SPAM)
              end
            end
          end
        end

        # this is a callback that comes from the acts_as_flaggable module.
        # This method is called any time is flag is created with this
        # instance as its subject (flaggable). We're using it to keep
        # the creator's spam_count up-to-date
        define_method(:flagged_with) do |flag, options|
          if flag.flag == Flag::SPAM
            if self.respond_to?(:user)
              self.user.update_spam_count
            end
          end
        end

      end

    end
  end
end

# added a disable attribute on the class which can be used to disable
# akismet API calls, for example when running specs which great tons
# of objects which would normally call the API in their after_save callback
module Rakismet
  class << self
    attr_accessor :disabled
  end
end
