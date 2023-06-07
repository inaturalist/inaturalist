# frozen_string_literal: true

# Override strftime in date classes to allow a custom `=` modifier that
# downcases the month to accommodate languages where that's a convention

# TODO: figure out how to DRY this out a bit

class Date
  alias old_strftime strftime

  def strftime( format = "%F" )
    old_strftime(
      format.
        gsub( "%=B", old_strftime( "%B" ).downcase ).
        gsub( "%=b", old_strftime( "%b" ).downcase )
    )
  end
end

class Time
  alias old_strftime strftime

  def strftime( format = "%F" )
    old_strftime(
      format.
        gsub( "%=B", old_strftime( "%B" ).downcase ).
        gsub( "%=b", old_strftime( "%b" ).downcase )
    )
  end
end

class DateTime
  alias old_strftime strftime

  def strftime( format = "%F" )
    old_strftime(
      format.
        gsub( "%=B", old_strftime( "%B" ).downcase ).
        gsub( "%=b", old_strftime( "%b" ).downcase )
    )
  end
end
