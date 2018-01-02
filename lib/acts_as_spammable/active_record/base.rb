module ActiveRecord
  class Base
    class << self

      def acts_as_spammable(options={})

        include Rakismet::Model
        acts_as_flaggable

        rakismet_fields = options[:fields]
        rakismet_user = options[:user] || :user
        # set up the rakismet attributes. Concatenate multiple
        # fields using periods as if sentences
        rakismet_attrs author: proc { user_responsible ? user_responsible.name : nil },
                       author_email: proc { user_responsible ? user_responsible.email : nil },
                       content: proc {
                         options[:fields].map{ |f|
                           self.respond_to?(f) ? self.send(f) : nil
                         }.compact.join(". ")
                       },
                       comment_type: options[:comment_type],
                       blog_lang: "en,fr,es,zh,gl,th,jp"

        validate :user_cannot_be_spammer
        after_save :evaluate_user_spammer_status, unless: proc {
          user_responsible && user_responsible.known_non_spammer? }
        unless options[:automated] === false
          after_save :check_for_spam, unless: proc {
            (user_responsible && user_responsible.known_non_spammer?) ||
            (options[:checks_spam_unless] && self.send(options[:checks_spam_unless])) }
        end

        scope :flagged_as_spam,
          -> { joins(:flags).where({ flags: { flag: Flag::SPAM, resolved: false } }) }
        scope :not_flagged_as_spam, ->{ 
          s = joins("LEFT JOIN flags f ON (#{ table_name }.id=f.flaggable_id
              AND f.flaggable_type='#{ name }' AND f.flag='#{ Flag::SPAM }'
              AND resolved = false)").
            where("f.id IS NULL")
          if column_names.include?('user_id')
            s = s.joins(:user).where("(users.spammer = ? OR users.spammer IS NULL)", false)
          end
          s
        }

        define_method(:user_cannot_be_spammer) do
          if self.respond_to?(rakismet_user) && self.send(rakismet_user).is_a?(User) && self.send(rakismet_user).spammer?
            errors.add(rakismet_user, "cannot be spammer")
          end
        end

        define_method(:flagged_as_spam?) do
          self.flags.loaded? ?
            self.flags.any?{ |f| f.flag == Flag::SPAM && ! f.resolved? } :
            self.class.flagged_as_spam.exists?(self.id)
        end

        define_method(:default_life_list?) do
          self.is_a?(LifeList) &&
          self.title == self.default_title &&
          self.description == self.default_description
        end

        define_method(:has_spammable_content?) do
          # when all the fields we care about are blank, we don't have spam
          # and don't need to call the akismet API.
          ! rakismet_fields.all?{ |f| self.send(f).blank? }
        end

        define_method(:spammable_fields_changed?) do
          # if there is any overlap between the fields that could be spam
          # and the fields that have been changed this time around
          # & is the set intersection operator
          ( self.changed.map(&:to_sym) & rakismet_fields ).any?
        end

        # If any of the rakismet fields have been modified, then
        # call the akismet API and update the flags on this object.
        # Flags are made with user_id = 0, representing automated flags
        define_method(:check_for_spam) do
          return if default_life_list?
          # leveraging the new attribute `disabled`, which we set to
          # true if we are running tests. This can be overridden by using
          # before and after blocks and manually changing Rakismet.disabled
          if Rakismet.disabled.nil?
            Rakismet.disabled = Rails.env.test?
          end
          unless Rakismet.disabled
            if self.spammable_fields_changed?
              # This is also the only place that the akismet API is called outside of specs
              is_spam =  self.has_spammable_content? ? spam? : false
              if is_spam
                self.add_flag( flag: "spam", user_id: 0 )
              elsif self.flagged_as_spam?
                Flag.destroy_all(flaggable_id: self.id, flaggable_type: self.class,
                  user_id: 0, flag: Flag::SPAM, resolved: false)
              end
            end
          end
        end

        # this is a callback that comes from the acts_as_flaggable module.
        # This method is called any time is flag is created with this
        # instance as its subject (flaggable). We're using it to keep
        # the creator's spam_count up-to-date
        define_method(:flagged_with) do |flag, options|
          evaluate_new_flag_for_spam(flag)
        end

        define_method(:evaluate_new_flag_for_spam) do |flag|
          if flag.flag == Flag::SPAM
            if user_responsible
              user_responsible.update_spam_count
            end
            return unless has_spammable_content?
            if flag.resolved? || flag.destroyed?
              # akismet spam flag was resolved or deleted
              # tell akismet this is ham
              ham! if flag.is_akismet_spam_flag?
            elsif !flag.is_akismet_spam_flag?
              # non-akismet spam flag was created
              # as long as there are no open akismet spam flags, tell akismet this is spam
              akismet_unflagged = flags.select{ |f| f != flag && f.is_akismet_spam_flag? && !f.resolved }.empty?
              spam! if akismet_unflagged
            end
          end
        end

        define_method(:evaluate_user_spammer_status) do
          if user_responsible
            user_responsible.set_as_non_spammer_if_meets_criteria
          end
        end

        define_method(:user_responsible) do
          if self.is_a?(User)
            self
          elsif self.respond_to?(rakismet_user)
            self.send(rakismet_user)
          end
        end

      end

      def spammable?
        respond_to?(:flagged_as_spam)
      end
    end

    # it would be nice to use flagged_as_spam? directly
    # but GuideTaxon is a weird case of something that is spam
    # only because of association - its not directly flagged
    def known_spam?
      if self.is_a?(GuideTaxon)
        # guide taxa can have many sections, each of which could be spam,
        # so when one is spam consider the entire GuideTaxon as spam
        if self.guide_sections.any?{ |s| s.flagged_as_spam? }
          return true
        end
        return false
      end
      if (self.respond_to?(:flagged_as_spam?) && self.flagged_as_spam?)
        return true
      end
      false
    end

    def owned_by_spammer?
      return false unless self.respond_to?(:user_responsible)
      return true if user_responsible && user_responsible.spammer?
      false
    end

  end
end
