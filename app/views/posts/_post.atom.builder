url = (@parent.is_a?(Project) ? 
       project_journal_post_url(:project_id => @parent_slug, :id => post) :
       journal_post_url(:login => @parent_slug, :id => post)) 
feed.entry(post, :url => url) do |entry|
  entry.title(post.title)
  entry.author do |author|
    author.name(post.user.login) if post.user
  end
  entry.content(markdown(auto_link(post.body)), :type => 'html')
end
