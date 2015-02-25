class Irwi::Comparators::Diffy
  def render_changes( old_text, new_text )
    Diffy::Diff.new(old_text.html_safe,new_text.html_safe).to_s(:html).html_safe
  end
end
Irwi.config.formatter = Irwi::Formatters::BlueCloth.new
Irwi.config.page_attachment_class_name = 'WikiPageAttachment'
Irwi.config.comparator = Irwi::Comparators::Diffy.new
