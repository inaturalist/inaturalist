module ActionController
  class Base
    class << self

      def blocks_spam(options={})
        before_filter :block_spammers, :only => options[:only],
          :except => options[:except]

        define_method(:block_if_spam) do |obj|
          return unless obj
          if obj.spam_or_owned_by_spammer?
            user = obj.is_a?(User) ? obj : obj.user
            (current_user == user) ? render_spam_owner : render_spam_viewer
          end
        end

        define_method(:block_spammers) do
          block_if_spam(instance_variable_get("@" + options[:instance].to_s))
        end
      end

    end
  end
end
