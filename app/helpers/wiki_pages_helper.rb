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
end
