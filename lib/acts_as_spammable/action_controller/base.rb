module ActionController
  class Base
    class << self

      def blocks_spam(options={})
        before_action :block_spammers, only: options[:only],
          except: options[:except]

        define_method(:block_if_spammer) do |obj|
          if obj.is_a?(User) && obj.spammer?
            if_spammer_set_flash_message(obj) && return
            render(template: "users/_suspended", status: 403, layout: "application")
          end
        end

        # if `obj` is spam, a spammer, or something created by a spammer
        # then render the corresponding 4xx page.
        # return the value of obj.spam_or_owned_by_spammer?
        define_method(:block_if_spam) do |obj|
          return unless obj
          user_to_check = obj.is_a?(User) ? obj : obj.user
          if obj.owned_by_spammer?
            if_spammer_set_flash_message(user_to_check) && return
            # all spammers are suspended, so show the suspended message page
            render(template: "users/_suspended", status: 403, layout: "application")
          elsif obj.known_spam?
            if_spammer_set_flash_message(user_to_check) && return
            # if the user isn't a spammer yet, but the content is,
            # then show the spam message page
            render_spam_notice
          end
        end

        # convenience method which takes an `instance` parameter
        # and evaluates the value of that variable at run-time. Might
        # be able to do this easier with some kind of Proc instead
        define_method(:block_spammers) do
          block_if_spam(instance_variable_get("@" + options[:instance].to_s))
        end

        # render a custom page for people seeing SPAM
        # with response code 403 Forbidden
        define_method(:render_spam_notice) do
          render(template: "shared/spam", status: 403, layout: "application")
        end

        define_method(:set_spam_flash_error) do
          flash.now[:warning_title] = t("views.shared.spam.this_has_been_flagged_as_spam")
          flash.now[:warning] = t("views.shared.spam.message_for_owner_and_curators_html", email: @site.email_help)
        end

        define_method(:if_spammer_set_flash_message) do |user_to_check|
          curator_or_site_admin = current_user && (
            current_user.is_curator? ||
            current_user.is_site_admin_of?( user_to_check.site )
          )
          if current_user == user_to_check || curator_or_site_admin
            set_spam_flash_error
            return true
          end
        end
      end

      # Set instance variables on an instance that acts_as_spammable will use
      # when checking with akismet. It seems like user_ip is the only one that's
      # really required, which we set for all users anyway, so this probably
      # isn't necessary, but it would probably help.
      def check_spam( options = {} )
        before_action :set_akismet_params_on_record, only: options[:only], except: options[:except]

        define_method( :set_akismet_params_on_record ) do
          return unless record = instance_variable_get( "@" + options[:instance].to_s )
          # if we checking for spam when creating / updating a user and the
          # current user is not that user (e.g. curator or admin action), we
          # don't want to send akismet the current user's info
          if record.is_a?( User ) && current_user && current_user != record
            return
          end
          # No point in setting this info if we know this user isn't a spammer
          return if current_user && current_user.known_non_spammer?
          record.acts_as_spammable_user_ip = Logstasher.ip_from_request_env( request.env )
          record.acts_as_spammable_user_agent = request.user_agent
          record.acts_as_spammable_referrer = request.referrer
        end
      end

    end
  end
end
