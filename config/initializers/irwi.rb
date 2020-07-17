class Irwi::Comparators::Diffy
  def render_changes( old_text, new_text )
    Diffy::Diff.new(old_text.html_safe,new_text.html_safe).to_s(:html).html_safe
  end
end

class Irwi::Formatters::Redcarpet
  def initialize
    require "redcarpet"
  end

  def format( text )
    Redcarpet::Markdown.new( Redcarpet::Render::HTML,
      tables: true,
      disable_indented_code_blocks: true,
      lax_spacing: true,
      no_intra_emphasis: true
    ).render( text )
  end
end

Irwi.config.formatter = Irwi::Formatters::Redcarpet.new
Irwi.config.page_attachment_class_name = 'WikiPageAttachment'
Irwi.config.comparator = Irwi::Comparators::Diffy.new
