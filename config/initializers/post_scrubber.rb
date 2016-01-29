#
# Custom scrubber for posts that allows any CSS in a style attribute.
#
class PostScrubber < Rails::Html::PermitScrubber
  def initialize( options )
    self.tags = options[:tags] if options[:tags]
    self.attributes = options[:attributes] if options[:attributes]
  end
  def scrub_css_attribute(node)
    # Do nothing, default is too agressive and removes positioning styles  
  end
end
