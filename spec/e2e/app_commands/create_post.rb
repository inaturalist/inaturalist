# frozen_string_literal: true

# Post's blueprint derives parent from a `user` object, which JSON factory calls can't pass.
opts = command_options.transform_keys( &:to_sym )
user = User.find( opts[:user_id] )
post = Post.make!( {
  user: user,
  parent: opts[:parent_type] ? opts[:parent_type].constantize.find( opts[:parent_id] ) : user,
  title: opts[:title] || Faker::Lorem.sentence,
  observations: Observation.where( id: opts[:observation_ids] ),
  body: opts[:body],
  tag_list: opts[:tag_list],
  blog_category_id: opts[:blog_category_id]
}.compact )
opts[:comment_count].to_i.times { Comment.make!( parent: post ) }
if opts[:cover]
  cover = PostImage.make!(
    post: post,
    user: user,
    alt: "An egg on a plain background",
    caption: "An egg",
    attribution: "Photo © #{user.login}"
  )
  post.update!( cover_image: cover )
end
post
