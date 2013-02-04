class WikiPage < ActiveRecord::Base
  acts_as_wiki_page
  ALLOWED_TAGS = %w(
    a abbr acronym b blockquote br cite code div dl dt em embed h1 h2 h3 h4 h5 h6 hr i
    iframe img li object ol p param pre small span strong sub sup tt ul
  )
  ALLOWED_ATTRIBUTES = %w(
    abbr
    align
    alt
    cite
    class
    height
    href
    name
    src
    style
    title
    value
    width
    xml:lang
  )

  before_save :downcase_path

  def self.find_by_path(path)
    super(path.to_s.downcase)
  end

  def downcase_path
    self.path = self.path.downcase if self.path
    true
  end
end
