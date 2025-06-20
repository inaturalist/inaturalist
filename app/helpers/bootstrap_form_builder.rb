# frozen_string_literal: true

class BootstrapFormBuilder < DefaultFormBuilder
  def description_tip( description )
    content_tag(
      :button,
      content_tag( :i, "", class: "fa fa-info-circle" ),
      class: "btn btn-nostyle",
      data: {
        toggle: "popover",
        content: description,
        placement: "bottom"
      },
      onclick: "return false;"
    )
  end

  def form_field( field, field_content = nil, options = {}, &block )
    options = field_content if block_given?
    options ||= {}
    label_after = options.delete( :label_after )
    description_after = options.delete( :description_after )
    wrapper_options = options.delete( :wrapper ) || {}
    wrapper_options[:class] = "#{wrapper_options[:class]} field #{field.to_s.parameterize.underscore}_field".strip
    content = ""
    label_content = ""
    description = content_tag( :p, options[:description], class: "help-block" ) if options[:description]
    content = "#{content}#{block_given? ? @template.capture( &block ) : field_content}"

    datalist = nil
    if options[:datalist]
      datalist = content_tag(
        :datalist,
        options[:datalist].map {| item | content_tag( :option, item, value: item ) }.join( "\n" ).html_safe,
        id: dom_id( object, "#{field}-datalist" )
      )
    end

    if %w(check_box radio_button).include?( options[:field_name] )
      return check_radio_field( field, field_content, options, wrapper_options, description )
    end

    if options[:label] != false
      label_field = field
      label_inside = (
        options[:label] ||
        I18n.t( "activerecord.attributes.#{object.class.name.underscore}.#{field}", default: field.to_s.humanize )
      ).to_s.html_safe
      if options[:description_tip]
        label_inside += description_tip( description )
      end
      label_tag = label(
        label_field,
        label_inside,
        class: options[:label_class],
        for: options[:id]
      )
      if options[:required]
        label_tag += content_tag( :span, " *", class: "required" )
      end
      label_content = content_tag( label_after ? :span : :div, label_tag, class: "inlabel" )
    end

    content = if label_after
      "#{content} #{datalist} #{label_content} #{description}"
    elsif description_after
      "#{label_content} #{content} #{datalist} #{description}"
    elsif options[:description_tip]
      "#{label_content} #{content} #{datalist}"
    else
      "#{label_content} #{description} #{content} #{datalist}"
    end
    @template.content_tag( :div, content.html_safe, wrapper_options )
  end

  %w(text_field text_area).each do | name |
    define_method( name ) do | field, *args, &block |
      options = args.last.is_a?( Hash ) ? args.last : {}
      return super( field, *args, &block ) if options[:skip_builder]

      args << {} unless args.last.is_a?( Hash )
      args.last[:class] = [args.last[:class], "form-control"].flatten.join( " " )
      super( field, *args, &block )
    end
  end

  def select( method, choices = nil, options = {}, html_options = {}, &block )
    unless options[:skip_builder]
      html_options[:class] = [html_options[:class], "form-control"].join( " " )
    end
    super( method, choices, options, html_options, &block )
  end

  def check_radio_field( field, field_content = nil, options = {}, wrapper_options = {}, description = nil )
    css_classes = wrapper_options[:class].to_s.split.reject {| klass | klass == "form-group" }
    css_classes << ( options[:field_name] == "check_box" ? "checkbox" : "radio" )
    wrapper_options[:class] = css_classes.join( " " )
    label_content = if options[:label] == false
      nil
    else
      options[:label] ||
        I18n.t( "activerecord.attributes.#{object.class.name.underscore}.#{field}", default: nil ) ||
        field
    end
    label_content += description_tip( description ) if options[:description_tip]
    label_content = label_content.to_s.html_safe
    if options[:required]
      label_content += content_tag( :span, " *", class: "required" )
    end
    label_class = if options[:inline]
      field == "check_box" ? "checkbox-inline" : "radio-inline"
    end
    content = @template.content_tag( :label, [field_content, label_content].join( " " ).html_safe, class: label_class )
    if !options[:description_tip] && !description.blank?
      content += @template.content_tag( :div, description.html_safe )
    end
    if options[:inline]
      return content
    end

    @template.content_tag( :div, wrapper_options ) do
      content
    end
  end
end
