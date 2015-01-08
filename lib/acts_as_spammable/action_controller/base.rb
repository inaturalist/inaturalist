module ActionController
  class Base
    class << self

      def blocks_spam(options={})
        before_filter :block_spammers, :only => options[:only],
          :except => options[:except]

        # if `obj` is spam, a spammer, or something created by a spammer
        # then render the corresponding 4xx page.
        # return the value of obj.spam_or_owned_by_spammer?
        define_method(:block_if_spam) do |obj|
          return unless obj
          if obj.owned_by_spammer?
            if current_user == obj.user || (current_user && current_user.is_curator?)
              set_spam_flash_error
              return false
            end
            # all spammers are suspended, so show the suspended message page
            render(template: "users/_suspended", status: 403, layout: "application")
          elsif obj.known_spam?
            if current_user == obj.user|| (current_user && current_user.is_curator?)
              set_spam_flash_error
              return false
            end
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
          flash[:error] = [ t("views.shared.spam.this_has_been_flagged_as_spam"),
            t("views.shared.spam.if_you_think_your_content_html", email: CONFIG.help_email) ].join(".<br/>")
        end
      end

    end
  end
end
