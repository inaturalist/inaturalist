feed.entry(observation) do |entry|
  entry.title(observation.species_guess)
  entry.author do |author|
    author.name(observation.user.login)
  end
  content = ""
  unless observation.photos.blank?
    photo_content = observation.photos.map do |p|
      image_tag(p.try_methods(:medium_url, :small_url, :thumb_url))
    end.join(' ')
    content += content_tag(:p, photo_content.html_safe)
  end
  content += auto_link(simple_format(observation.description)) if observation.description
  entry.content(content, :type => 'html')
  if observation.latitude and observation.longitude
    entry.georss(:point, "#{observation.latitude} #{observation.longitude}")
  end
end
