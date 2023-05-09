class FlickrIdentity < ApplicationRecord
  belongs_to :user

  def source_options
    {
      :title => 'Flickr', 
      :url => '/flickr/photo_fields', 
      :contexts => [
        ["Your photos", 'user', {:searchable => true}]
      ]
    }
  end
end
