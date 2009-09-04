feed.entry(observation) do |entry|
  entry.title(observation.species_guess)
  entry.author do |author|
    author.name(observation.user.login)
  end
  content = observation.flickr_photos.map do |p|
    image_tag(p.thumb_url, :align => 'left')
  end.join(' ')
  content += observation.description if observation.description
  entry.content(content, :type => 'html')
  if observation.latitude and observation.longitude
    entry.georss(:point, "#{observation.latitude} #{observation.longitude}")
  end
end
