class LocalSound < Sound
  if Rails.env.production?
    has_attached_file :file,
      preserve_files: true,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: "https",
      s3_host_alias: CONFIG.s3_bucket,
      bucket: CONFIG.s3_bucket,
      path: "sounds/:id.:content_type_extension",
      url: ":s3_alias_url"
    invalidate_cloudfront_caches :file, "sounds/:id.*"
  else
    has_attached_file :file,
      path: ":rails_root/public/attachments/:class/:attachment/:id.:content_type_extension",
      url: "/attachments/:class/:attachment/:id.:content_type_extension"
  end

  validates_attachment_content_type :file,
    content_type: [/wav/i, /mpeg/i, /mp3/i, /m4a/i],
    message: "must be a WAV, MP3, or M4A"

  def to_observation
    o = Observation.new
    o.sounds.build( self.attributes )
    o
  end
end
