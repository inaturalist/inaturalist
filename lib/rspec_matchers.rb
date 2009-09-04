module ClassMatchers
  class BeA
    def initialize(expected)
      @expected = expected
    end

    def matches?(target)
      @target = target
      @target.is_a?(@expected)
    end

    def failure_message
      "expected a #{@expected.class.name}, " + 
      "got a #{@target.class.name} instead"
    end

    def negative_failure_message # not sure if this is right...
      "didn't expected a #{@expected.class.name}, " + 
      "got a #{@target.class.name}"
    end
  end
  
  def be_a(expected)
    BeA.new(expected)
  end
  alias_method :be_an, :be_a
  
  class BehaveLikeA
    def initialize(expected)
      @expected = expected
    end

    def matches?(target)
      @target = target
      @expected.instance_methods.each do |m|
        return false unless @target.respond_to? m
      end
      true
    end

    def failure_message
      "#{@target.class.name} doesn't behave like a #{@expected}"
    end

    def negative_failure_message
      "#{@target} behaves like a #{@expected}"
    end
  end
  
  def behave_like_a(expected)
    BehaveLikeA.new(expected)
  end
  alias_method :behave_like_an, :behave_like_a

end
