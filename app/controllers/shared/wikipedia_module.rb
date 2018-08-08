module Shared::WikipediaModule
  def wikipedia
    @title ||= params[:id]
    coder = HTMLEntities.new
    w = @wikipedia = WikipediaService.new
    @decoded = ""
    begin
      query_results = w.query(
        :titles => @title, 
        :redirects => '', 
        :prop => 'revisions', 
        :rvprop => 'content')
      raw = query_results.blank? ? nil : query_results.at('page')
      unless raw.blank? || raw['missing']
        parsed = w.parse(:page => raw['title']).at('text').try(:inner_text).to_s
        @decoded = coder.decode(parsed)
        @decoded.gsub!('href="//', 'href="http://')
        @decoded.gsub!('src="//', 'src="http://')
        @decoded.gsub!('href="/', 'href="' + w.base_url + '/')
        @decoded.gsub!('src="/', 'src="' + w.base_url + '/')
        filter_wikipedia_content
      end
    rescue Timeout::Error => e
      Rails.logger.info "[INFO] Wikipedia API call failed: #{e.message}"
    end
    
    respond_to do |format|
      format.html do
        if @decoded.empty?
          render(:text => "#{@before_wikipedia} Wikipedia doesn't have a page for #{@title}", :status => 404)
        else
          render(:text => "#{@before_wikipedia} #{@decoded}")
        end
      end
    end
  rescue SocketError => e
    raise unless Rails.env.development?
    Rails.logger.debug "[DEBUG] Looks like you're offline, skipping wikipedia"
    render :text => "You're offline."
  end
  
  private
  
  # Override and filter the contents of @decoded if you need to
  def filter_wikipedia_content
  end
end
