url = flexible_post_url( post )
feed.entry(post, :url => url) do |entry|
  entry.title(post.title)
  entry.author do |author|
    author.name(post.user.login) if post.user
  end
  entry.content(markdown(auto_link(post.body)), :type => 'html')
end
