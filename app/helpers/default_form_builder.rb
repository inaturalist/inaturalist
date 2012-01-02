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
  
  class INatInstanceTag < ActionView::Helpers::InstanceTag
    def to_select_tag_with_option_tags(option_tags, options, html_options)
      html_options = html_options.stringify_keys
      add_default_name_and_id(html_options)
      value = value(object)
      selected_value = options.has_key?(:selected) ? options[:selected] : value
      disabled_value = options.has_key?(:disabled) ? options[:disabled] : nil
      content_tag("select", add_options(option_tags, options, selected_value), html_options)
    end
  end
  
  # Override to get better attrs in there
  def time_zone_select(method, priority_zones = nil, options = {}, html_options = {})
    html_options[:class] = "#{html_options[:class]} time_zone_select"
    zone_options = ""
    selected = options.delete(:selected)
    model = options.delete(:model) || ActiveSupport::TimeZone
    zones = model.all
    convert_zones = lambda {|list, selected| 
      list.map do |z|
        opts = {
          :value => z.name, 
          "data-time-zone-abbr" => z.tzinfo.current_period.abbreviation, 
          "data-time-zone-tzname" => z.tzinfo.name,
          "data-time-zone-offset" => z.utc_offset,
          "data-time-zone-formatted-offset" => z.formatted_offset
        }
        opts[:selected] = "selected" if selected == z.name
        content_tag(:option, z.to_s, opts)
      end.join("\n")
    }
    if priority_zones
      if priority_zones.is_a?(Regexp)
        priority_zones = model.all.find_all {|z| z =~ priority_zones}
      end
      zone_options += convert_zones.call(priority_zones, selected)
      zone_options += "<option value=\"\" disabled=\"disabled\">-------------</option>\n"
      zones = zones.reject { |z| priority_zones.include?( z ) }
    end
    zone_options += convert_zones.call(zones, selected)
    tag = INatInstanceTag.new(
      object_name, method, self, options.delete(:object)
    ).to_select_tag_with_option_tags(zone_options, options, html_options)
    form_field method, tag, options.merge(html_options)
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
    
    
    description = content_tag(:div, options[:description], :class => "description") if options[:description]
    content = "#{content}#{block_given? ? @template.capture(&block) : field_content}"
    
    content = if options[:label_after]
      "#{content} #{label_content} #{description}"
    else
      "#{label_content} #{description} #{content}"
    end
    
    if block_given?
      @template.concat @template.content_tag(:div, content, wrapper_options)
    else
      @template.content_tag(:div, content, wrapper_options)
    end
  end
  
end
