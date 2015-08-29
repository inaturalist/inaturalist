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
      label_tag = label(label_field, options[:label].to_s.html_safe, :class => options[:label_class], :for => options[:id])
      if options[:required]
        label_tag += content_tag(:span, " *", :class => 'required')
      end
      label_content = content_tag(options[:label_after] ? :span : :div, label_tag, :class => "inlabel")
    end
    
    content = if options[:label_after]
      "#{content} #{label_content} #{description}"
    else
      "#{label_content} #{content} #{description}"
    end
    @template.content_tag(:div, content.html_safe, wrapper_options)
  end

  %w(text_field text_area).each do |name|
    define_method(name) do |field, *args, &block|
      options = args.last.is_a?(Hash) ? args.last : {}
      return super(field, *args, &block) if options[:skip_builder]
      args << {} unless args.last.is_a?(Hash)
      args.last[:class] = [args.last[:class], 'form-control'].flatten.join(' ')
      super(field, *args, &block)
    end
  end

  def select(method, choices = nil, options = {}, html_options = {}, &block)
    unless options[:skip_builder]
      html_options[:class] = [html_options[:class], 'form-control'].join(' ')
    end
    super(method, choices, options, html_options, &block)
  end

  def check_radio_field(field, field_content = nil, options = {}, wrapper_options = {}, description = nil)
    wrapper_options[:class] = wrapper_options[:class].gsub('form-group', field == 'check_box' ? 'checkbox' : 'radio')
    label_content = (options[:label] == false ? nil : options[:label] || field).to_s.html_safe
    if options[:required]
      label_content += content_tag(:span, " *", :class => 'required')
    end
    @template.content_tag(:div, wrapper_options) do
      @template.content_tag(:label, [field_content, label_content].join(' ').html_safe)
    end
  end
end
