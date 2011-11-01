class DefaultFormBuilder < ActionView::Helpers::FormBuilder
  include ActionView::Helpers::TagHelper
  helpers = field_helpers +
            %w{date_select datetime_select time_select} +
            %w{collection_select select country_select time_zone_select} -
            %w{hidden_field label fields_for} # Don't decorate these
  
  helpers.each do |name|
    define_method(name) do |field, *args|
      options = if args[-2].is_a?(Hash)
        args.pop
      elsif args.last.is_a?(Hash)
        args.last
      else
        {}
      end
      if %w(text_field file_field).include?(name.to_s)
        css_class = options[:class] || []
        css_class = [css_class, 'text'].flatten.uniq.join(' ') if name.to_s == "text_field"
        css_class = [css_class, 'file'].flatten.uniq.join(' ') if name.to_s == "file_field"
        args << {} unless args.last.is_a?(Hash)
        args.last[:class] = css_class
      end
      content = super(field, *args)
      form_field(field, content, options)
    end
  end
  
  def form_field(field, field_content = nil, options = {}, &block)
    options = field_content if block_given?
    options ||= {}
    wrapper_options = options.delete(:wrapper) || {}
    wrapper_options[:class] = "#{wrapper_options[:class]} field #{field}_field".strip
    content, label_content = '', ''
    
    if options[:label] != false
      label_tag = label(field, options[:label], :class => options[:label_class])
      if options[:required]
        label_tag += content_tag(:span, " *", :class => 'required')
      end
      label_content = content_tag(options[:label_after] ? :span : :div, label_tag, :class => "label")
    end
    
    if options[:description]
      content += content_tag(:div, options[:description], :class => "description")
    end
    
    content = "#{content}#{block_given? ? @template.capture(&block) : field_content}"
    
    content = if options[:label_after]
      "#{content} #{label_content}"
    else
      "#{label_content} #{content}"
    end
    
    if block_given?
      @template.concat @template.content_tag(:div, content, wrapper_options)
    else
      @template.content_tag(:div, content, wrapper_options)
    end
  end
  
end
