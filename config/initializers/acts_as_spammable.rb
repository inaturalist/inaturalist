module ActionController
  class Base
    class << self

      def blocks_spam(options={})
        before_filter :block_spammers, :only => options[:only],
          :except => options[:except]

        define_method(:spam_or_owned_by_spammer?) do |obj|
          if obj.is_a?(GuideTaxon)
            if obj.guide_sections.any?{ |s| s.flagged_as_spam? }
              return true
            end
            obj = obj.guide
          end
          user = obj.is_a?(User) ? obj : obj.user
          if (user && user.spammer?) ||
            (obj.respond_to?(:flagged_as_spam?) && obj.flagged_as_spam?)
            return true
          end
          false
        end

        define_method(:block_if_spam) do |obj|
          return unless obj
          if spam_or_owned_by_spammer?(obj)
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


module ActiveRecord
  class Base
    class << self

      def acts_as_spammable(options={})

        include Rakismet::Model

        rakismet_fields = options[:fields]
        # set up the rakismet attributes. Concatenate multiple
        # fields using periods as if sentences
        rakismet_attrs :author => proc { self.user ? self.user.name : nil },
                       :author_email => proc { self.user ? self.user.email : nil },
                       :content => proc {
                         options[:fields].map{ |f|
                           self.respond_to?(f) ? self.send(f) : nil
                         }.compact.join(". ")
                       },
                       :comment_type => options[:comment_type]

        after_save :check_for_spam
        scope :flagged_as_spam,
          joins(:flags).where({ flags: { flag: Flag::SPAM } })

        class << self
          define_method(:spammable?) do
            true
          end
        end

        define_method(:flagged_as_spam?) do
          self.class.flagged_as_spam.exists?(self)
        end

        # If any of the rakismet fields have been modified, then
        # call the akismet API and update the flags on this object.
        # Flags are made with user_id = 0, representing automated flags
        define_method(:check_for_spam) do
          # leveraging the new attribute `disabled`, which we set to
          # true if we are running tests. This can be overridden by using
          # before and after blocks and manually changing Rakismet.disabled
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

    # added pps for debugging
    def akismet_call(function, args={})
      validate_config
      args.merge!(:blog => Rakismet.url, :is_test => Rakismet.test_mode)
      pp args
      akismet = URI.parse(call_url(function))
      pp akismet
      response = Net::HTTP::Proxy(proxy_host, proxy_port).start(akismet.host) do |http|
        params = args.map do |k,v|
          param = v.class < String ? v.to_str : v.to_s # for ActiveSupport::SafeBuffer and Nil, respectively
          "#{k}=#{CGI.escape(param)}"
        end
        http.post(akismet.path, params.join('&'), Rakismet.headers)
      end
      puts response.body
      response.body
    end

  end
end
