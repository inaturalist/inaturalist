# frozen_string_literal: true

module PostsHelper
  def with_scrollable_tables( html )
    fragment = Nokogiri::HTML::DocumentFragment.parse( html )
    fragment.css( "table" ).reject {| table | table.ancestors( "table" ).any? }.each do | table |
      table.wrap( "<div class=\"post-article__table-scroll\"></div>" )
    end
    fragment.to_s.html_safe
  end
end
