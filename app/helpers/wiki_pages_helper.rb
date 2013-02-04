module WikiPagesHelper
  acts_as_wiki_pages_helper
  def wiki_content(text)
    Irwi.config.formatter.format(wiki_macros(wiki_linkify( wiki_show_attachments(text)))).html_safe
  end

  def wiki_macros(text)
    wiki_nav(text)
  end

  def wiki_nav(text)
    text.gsub(/\{\{nav.*?\}\}/) do |match|
      page_titles = match[/nav(.*?)\}/, 1].split(',')
      html = "<ul class='leftmenu'>"
      page_titles.each do |page_title|
        page_title.strip!
        link_class = @page && @page.title.downcase == page_title.downcase ? 'active' : nil
        html += content_tag :li do
          link_to page_title, wiki_link(page_title), :class => link_class
        end
      end
      html += "</ul>"
      html
    end
  end

  def wiki_page_attachments(page = @page)
    return unless Irwi::config.page_attachment_class_name

    html = ""
    page.attachments.each do |attachment|
      img = "<a target=\"_blank\" href=\"#{attachment.wiki_page_attachment.url(:original)}\">#{image_tag(attachment.wiki_page_attachment.url(:thumb))}</a>".html_safe
      html += image_and_content(img, :image_size => 100, 
          :class => "stacked wiki_page_attachment") do
        s = link_to(wt('Remove'), wiki_remove_page_attachment_path(attachment.id), :method => :delete, :class => "right")
        s += content_tag(:label, "html")
        s += "<br/>".html_safe
        s += content_tag(:textarea, "<img src=\"#{attachment.wiki_page_attachment.url(:original)}\"/>")
        s.html_safe
      end
    end

    html += form_for(Irwi.config.page_attachment_class.new,
             :as => :wiki_page_attachment,
             :url => wiki_add_page_attachment_path(page),
             :html => { :multipart => true }) do |form|
      "<label>Add an attached image</label><br/>".html_safe +
      form.file_field(:wiki_page_attachment) +
      form.hidden_field(:page_id, :value => page.id) +
      form.submit('Add attachment')
    end
    html.html_safe
  end
end
