class BootstrapFormBuilder < DefaultFormBuilder
  def form_field(field, field_content = nil, options = {}, &block)
    options = field_content if block_given?
    options ||= {}
    wrapper_options = options.delete(:wrapper) || {}
    wrapper_options[:class] = "#{wrapper_options[:class]} field #{field.to_s.parameterize.underscore}_field".strip
    content, label_content = '', ''
    description = content_tag(:p, options[:description], :class => "help-block") if options[:description]
    content = "#{content}#{block_given? ? @template.capture(&block) : field_content}"

    if %w(check_box radio_button).include?(options[:field_name])
      return check_radio_field(field, field_content, options, wrapper_options, description)
    end
    
    if options[:label] != false
      label_field = field
      # if options[:field_name] == 'radio_button'
      #   label_field = [label_field, options[:field_value]].compact.join('_').gsub(/\W/, '').downcase
      # end
      label_tag = label(label_field, options[:label].to_s.html_safe, :class => options[:label_class], :for => options[:id])
      if options[:required]
        label_tag += content_tag(:span, " *", :class => 'required')
      end
      label_content = content_tag(options[:label_after] ? :span : :div, label_tag, :class => "inlabel")
    end
    
    content = if options[:label_after]
      "#{content} #{label_content} #{description}"
    elsif options[:description_after]
      "#{label_content} #{content} #{description}"
    else
      "#{label_content} #{description} #{content}"
    end
    
    @template.content_tag(:div, content.html_safe, wrapper_options)
  end

  def check_radio_field(field, field_content = nil, options = {}, wrapper_options = {}, description = nil)
    wrapper_options[:class] = wrapper_options[:class].gsub('form-group', field == 'check_box' ? 'checkbox' : 'radio')
    label_content = options[:label].to_s.html_safe
    if options[:required]
      label_content += content_tag(:span, " *", :class => 'required')
    end
    @template.content_tag(:div, wrapper_options) do
      @template.content_tag(:label, field_content + label_content)
    end
  end
end
