# Some common errors we use for various auth strategies
module INat
  module Auth
    # When username and password don't match a user
    class BadUsernamePasswordError < StandardError; end
    # When a user tries to signup without an email, e.g. via third party
    class MissingEmailError < StandardError; end
    # User is suspended
    class SuspendedError < StandardError; end
    # User is a known child without parental permission
    class ChildWithoutPermissionError < StandardError; end
    # User has not confirmed their email address yet
    class UnconfirmedError < StandardError; end
    # User has tried to use the oauth assertion flow with a bad assertion type
    class BadAssertionTypeError < StandardError; end
  end
end
