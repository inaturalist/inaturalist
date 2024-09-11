# frozen_string_literal: true

module ActiveRecord
  class Base
    class << self
      def acts_as_spammable( options = {} )
        include Rakismet::Model
        acts_as_flaggable

        attr_accessor :acts_as_spammable_user_ip
        attr_accessor :acts_as_spammable_user_agent
        attr_accessor :acts_as_spammable_referrer

        rakismet_fields = options[:fields]
        rakismet_user = options[:user] || :user
        # set up the rakismet attributes. Concatenate multiple
        # fields using periods as if sentences
        rakismet_attrs author: proc { user_responsible ? user_responsible.published_name : nil },
          author_email: proc { user_responsible ? user_responsible.email : nil },
          user_ip: proc { acts_as_spammable_user_ip || user_responsible.try( :last_ip ) },
          user_agent: proc { acts_as_spammable_user_agent },
          referrer: proc { acts_as_spammable_referrer },
          content: proc {
            options[:fields].map do | f |
              respond_to?( f ) ? send( f ) : nil
            end.compact.join( ". " )
          },
          comment_type: options[:comment_type],
          blog_lang: I18N_SUPPORTED_LOCALES.join( "," )

        validate :user_cannot_be_spammer, on: :create
        after_save :evaluate_user_spammer_status, unless: proc {
          user_responsible && user_responsible.known_non_spammer?
        }
        unless options[:automated] == false
          after_save :check_for_spam, unless: proc {
            ( user_responsible && user_responsible.known_non_spammer? ) ||
              ( options[:checks_spam_unless] && send( options[:checks_spam_unless] ) )
          }
        end

        scope :flagged_as_spam,
          -> { joins( :flags ).where( { flags: { flag: Flag::SPAM, resolved: false } } ) }
        scope :not_flagged_as_spam, lambda {
          s = joins( "LEFT JOIN flags f ON (#{table_name}.id=f.flaggable_id
              AND f.flaggable_type='#{name}' AND f.flag='#{Flag::SPAM}'
              AND resolved = false)" ).
            where( "f.id IS NULL" )
          if column_names.include?( "user_id" )
            s = s.joins( :user ).where( "(users.spammer = ? OR users.spammer IS NULL)", false )
          end
          s
        }

        define_method( :user_cannot_be_spammer ) do
          if respond_to?( rakismet_user ) && send( rakismet_user ).is_a?( User ) &&
              send( rakismet_user ).spammer?
            errors.add( rakismet_user, "cannot be spammer" )
          end
        end

        define_method( :flagged_as_spam? ) do
          if flags.loaded?
            flags.any? {| f | f.flag == Flag::SPAM && !f.resolved? }
          else
            self.class.flagged_as_spam.exists?( id )
          end
        end

        # rubocop:disable Naming/PredicateName
        define_method( :has_spammable_content? ) do
          # when all the fields we care about are blank, we don't have spam
          # and don't need to call the akismet API.
          !rakismet_fields.all? {| f | send( f ).blank? }
        end
        # rubocop:enable Naming/PredicateName

        define_method( :spammable_fields_changed? ) do
          # if there is any overlap between the fields that could be spam
          # and the fields that have been changed this time around
          # & is the set intersection operator
          ( saved_changes.keys.map( &:to_sym ) & rakismet_fields ).any?
        end

        # If any of the rakismet fields have been modified, then
        # call the akismet API and update the flags on this object.
        # Flags are made with user_id = 0, representing automated flags
        define_method( :check_for_spam ) do | check_options = {} |
          # leveraging the new attribute `disabled`, which we set to
          # true if we are running tests. This can be overridden by using
          # before and after blocks and manually changing Rakismet.disabled
          if Rakismet.disabled.nil?
            Rakismet.disabled = Rails.env.test?
          end
          if !Rakismet.disabled && spammable_fields_changed?
            # This is also the only place that the akismet API is called outside of specs
            is_spam = has_spammable_content? ? spam? : false
            if is_spam
              add_flag( flag: "spam", user_id: 0 )
            elsif flagged_as_spam?
              Flag.destroy_all( flaggable_id: id, flaggable_type: self.class,
                user_id: 0, flag: Flag::SPAM, resolved: false )
            elsif check_options[:retry].to_i < 2
              delay(
                run_at: 15.minutes.from_now,
                unique_hash: { "#{self.class.name}::check_for_spam": id }
              ).check_for_spam( retry: check_options[:retry].to_i + 1 )
            end
          end
        end

        # this is a callback that comes from the acts_as_flaggable module.
        # This method is called any time is flag is created with this
        # instance as its subject (flaggable). We're using it to keep
        # the creator's spam_count up-to-date
        define_method( :flagged_with ) do | flag, _options |
          evaluate_new_flag_for_spam( flag )
        end

        define_method( :evaluate_new_flag_for_spam ) do | flag |
          if flag.flag == Flag::SPAM
            user_responsible&.update_spam_count
            return unless has_spammable_content?

            if flag.resolved? || flag.destroyed?
              # akismet spam flag was resolved or deleted
              # tell akismet this is ham
              ham! if flag.akismet_spam_flag?
            elsif !flag.akismet_spam_flag?
              # non-akismet spam flag was created
              # as long as there are no open akismet spam flags, tell akismet this is spam
              akismet_unflagged = flags.select {| f | f != flag && f.akismet_spam_flag? && !f.resolved }.empty?
              spam! if akismet_unflagged
            end
          end
        end

        define_method( :evaluate_user_spammer_status ) do
          user_responsible&.set_as_non_spammer_if_meets_criteria
        end

        define_method( :user_responsible ) do
          if is_a?( User )
            self
          elsif respond_to?( rakismet_user )
            send( rakismet_user )
          end
        end
      end

      def spammable?
        respond_to?( :flagged_as_spam )
      end
    end

    # it would be nice to use flagged_as_spam? directly
    # but GuideTaxon is a weird case of something that is spam
    # only because of association - its not directly flagged
    def known_spam?
      if is_a?( GuideTaxon )
        # guide taxa can have many sections, each of which could be spam,
        # so when one is spam consider the entire GuideTaxon as spam
        if guide_sections.any?( &:flagged_as_spam? )
          return true
        end

        return false
      end
      if respond_to?( :flagged_as_spam? ) && flagged_as_spam?
        return true
      end

      false
    end

    def owned_by_spammer?
      return false unless respond_to?( :user_responsible )
      return true if user_responsible&.spammer?

      false
    end
  end
end
