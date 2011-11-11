module Delayed
  module MessageSending
    # Override send later to support priorities
    # TODO rails3 refactor, b/c more recent versions of DJ support this 
    # natively, I think
    def send_later(method, *args)
      priority = 0
      if args
        args.each_with_index do |a, i|
          next unless a.is_a?(Hash)
          args[i] = a.clone # don't modify in place!
          priority = args[i].delete(:dj_priority).to_i
          args.slice!(i) if args[i].blank?
        end
      end
      Delayed::Job.enqueue Delayed::PerformableMethod.new(self, method.to_sym, args), priority
    end
  end
end
