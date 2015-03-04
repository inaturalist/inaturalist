module ActionController
  class Base
    class << self

      def blocks_spam(options={})
        before_filter :block_spammers, only: options[:only],
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
          flash.now[:warning] = t("views.shared.spam.message_for_owner_and_curators_html", email: CONFIG.help_email)
        end

        define_method(:if_spammer_set_flash_message) do |user_to_check|
          if current_user == user_to_check || (current_user && current_user.is_curator?)
            set_spam_flash_error
            return true
          end
        end
      end

    end
  end
end
