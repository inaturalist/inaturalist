# nofollow strat from http://stackoverflow.com/a/5654101/720268, otherwise a direct lift of
# https://github.com/mislav/will_paginate/blob/master/lib/will_paginate/view_helpers/action_view.rb#L99
# which can't be sublcassed b/c it's protected
require 'will_paginate/view_helpers/link_renderer'
class INatLinkRenderer < WillPaginate::ViewHelpers::LinkRenderer

  def rel_value(page)
    case page
    when @collection.previous_page; 'prev nofollow' + (page == 1 ? ' start nofollow' : '')
    when @collection.next_page; 'next nofollow'
    when 1; 'start nofollow'
    else
      'nofollow'
    end
  end

  def default_url_params
    {}
  end

  def url(page)
    @base_url_params ||= begin
      url_params = merge_get_params(default_url_params)
      merge_optional_params(url_params)
    end

    url_params = @base_url_params.dup
    add_current_page_param(url_params, page)

    @template.url_for(url_params)
  end

  def merge_get_params(url_params)
    if @template.respond_to? :request and @template.request and @template.request.get?
      symbolized_update(url_params, @template.params)
    end
    url_params
  end

  def merge_optional_params(url_params)
    symbolized_update(url_params, @options[:params]) if @options[:params]
    url_params
  end

  def add_current_page_param(url_params, page)
    unless param_name.index(/[^\w-]/)
      url_params[param_name.to_sym] = page
    else
      page_param = parse_query_parameters("#{param_name}=#{page}")
      symbolized_update(url_params, page_param)
    end
  end

  private

  def parse_query_parameters(params)
    Rack::Utils.parse_nested_query(params)
  end
end
