# frozen_string_literal: true

module WikiPagesHelper
  acts_as_wiki_pages_helper
  def wiki_content( text )
    Irwi.config.formatter.format( wiki_macros( wiki_linkify( wiki_show_attachments( text ) ) ) ).html_safe
  end

  def wiki_macros( text )
    wiki_css( wiki_nav( text ) )
  end

  def wiki_nav( text )
    text.gsub( /\{\{nav.*?\}\}/ ) do | match |
      page_titles = match[/nav(.*?)\}/, 1].split( "," )
      html = "<ul class='leftmenu'>"
      page_titles.each do | page_title |
        page_title.strip!
        link_class = @page && @page.title.downcase == page_title.downcase ? "active" : nil
        html += content_tag :li do
          page = WikiPage.find_by_title( page_title )
          if page&.title != page_title
            page = WikiPage.find_by_path( page_title.parameterize )
          end
          link_to ( page&.title || page_title ), wiki_link( page&.path || page_title ), class: link_class
        end
      end
      html += "</ul>"
      html
    end
  end

  def wiki_topnav
    pattern = /\{\{topnav.*?\}\}/
    navtxt = @page.content[pattern, 0]
    return if navtxt.blank?

    @page.content.gsub!( pattern, "" )
    html = "<ul class='topmenu'>"
    page_titles = navtxt[/nav(.*?)\}/, 1].split( "," )
    page_titles.each do | page_title |
      page_title.strip!
      link_class = @page && @page.title.downcase == page_title.downcase ? "active" : nil
      html += content_tag :li do
        page = WikiPage.find_by_title( page_title )
        if page&.title != page_title
          page = WikiPage.find_by_path( page_title.parameterize )
        end
        link_to ( page&.title || page_title ), wiki_link( page&.path || page_title ), class: link_class
      end
    end
    html += "</ul>"
    raw html
  end

  def wiki_css( text )
    text.gsub( %r{<style.*?>(.*?)</style>}m ) do | match |
      content_for( :extracss ) { match.html_safe }
    end
  end

  def wiki_page_attachments( page = @page )
    return unless Irwi.config.page_attachment_class_name

    html = ""
    page.attachments.each do | attachment |
      img = if attachment.image?
        <<~HTML
          <a
            target="_blank"
            href="#{attachment.wiki_page_attachment.url( :original )}"
          >
            #{image_tag( attachment.wiki_page_attachment.url( :thumb ) )}
          </a>
        HTML
      else
        "<a target=\"_blank\" href=\"#{attachment.wiki_page_attachment.url( :original )}\">#{t :view}</a>"
      end
      html += image_and_content( img.html_safe, image_size: 100,
          class: "stacked wiki_page_attachment" ) do
        s = link_to(
          wt( "Remove" ),
          wiki_remove_page_attachment_path( attachment.id ),
          method: :delete,
          class: "right"
        )
        s += content_tag( :label, "html" )
        s += "<br/>".html_safe
        s += content_tag( :textarea, "<img src=\"#{attachment.wiki_page_attachment.url( :original )}\"/>" )
        s.html_safe
      end
    end

    html += form_for( Irwi.config.page_attachment_class.new,
      as: :wiki_page_attachment,
      url: wiki_add_page_attachment_path( page ),
      html: { multipart: true } ) do | form |
      "<label>Add an attached image</label><br/>".html_safe +
        form.file_field( :wiki_page_attachment ) +
        form.hidden_field( :page_id, value: page.id ) +
        form.submit( "Add attachment" )
    end
    html.html_safe
  end

  def wiki_user( user )
    "#{link_to( user_image( user ), user )} #{link_to_user( user )}".html_safe
  end
end
