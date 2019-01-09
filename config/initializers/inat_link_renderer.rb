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

    if @options[:url_helper]
      @template.send( @options[:url_helper], url_params )
    else
      @template.url_for(url_params)
    end
  end

  def merge_get_params(url_params)
    if @template.respond_to?(:request) && @template.request && @template.request.get?
      symbolized_update(url_params, @template.params.select{|k,v| k.to_s != 'host'}.symbolize_keys)
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

  protected

  def windowed_page_numbers
    inner_window, outer_window = @options[:inner_window].to_i, @options[:outer_window].to_i
    window_from = current_page - inner_window
    window_to = current_page + inner_window
    
    # adjust lower or upper limit if other is out of bounds
    if window_to > total_pages
      window_from -= window_to - total_pages
      window_to = total_pages
    end
    if window_from < 1
      window_to += 1 - window_from
      window_from = 1
      window_to = total_pages if window_to > total_pages
    end
    
    # these are always visible
    middle = window_from..window_to

    # left window
    if outer_window + 3 < middle.first # there's a gap
      left = (1..(outer_window + 1)).to_a
      left << :gap
    else # runs into visible pages
      left = 1...middle.first
    end

    # right window
    if total_pages - outer_window - 2 > middle.last # again, gap
      right = if @options[:skip_right]
        []
      else
        ((total_pages - outer_window)..total_pages).to_a
      end
      right.unshift :gap
    else # runs into visible pages
      right = (middle.last + 1)..total_pages
    end
    
    left.to_a + middle.to_a + right.to_a
  end


  private

  def parse_query_parameters(params)
    Rack::Utils.parse_nested_query(params)
  end
end
