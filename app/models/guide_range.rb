class GuideRange < ActiveRecord::Base
  belongs_to :guide_taxon, :inverse_of => :guide_ranges
  has_one :guide, :through => :guide_taxon
  after_save {|r| r.guide.expire_caches(:check_ngz => true)}
  after_destroy {|r| r.guide.expire_caches(:check_ngz => true)}

  has_attached_file :file, 
    :styles => {
      :original => {:geometry => "2048x2048>",  :auto_orient => false },
      :large    => {:geometry => "1024x1024>",  :auto_orient => false },
      :medium   => {:geometry => "500x500>",    :auto_orient => false },
      :small    => {:geometry => "240x240>",    :auto_orient => false },
      :thumb    => {:geometry => "100x100>",    :auto_orient => false },
      :square   => {:geometry => "75x75#",      :auto_orient => false }
    },
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :s3_host_alias => CONFIG.s3_bucket,
    :bucket => CONFIG.s3_bucket,
    :path => "guide_maps/:id-:style.:extension",
    :url => ":s3_alias_url",
    :default_url => "/attachment_defaults/local_photos/:style.png"
  validates_attachment_content_type :file, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/], 
    :message => "must be JPG, PNG, or GIF"

  validates_attachment_content_type :file, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/], 
    :message => "must be JPG, PNG, or GIF"
    
  def to_s
    "<GuideRange #{id}>"
  end

  def attribution
    return I18n.t(:public_domain) if license == Photo::PD_CODE
    if license.blank?
      I18n.t('copyright.all_rights_reserved', :name => attribution_name)
    else
      I18n.t('copyright.some_rights_reserved_by', :name => attribution_name, :license_short => license)
    end
  end

  def attribution_name
    rights_holder_name ||= rights_holder unless rights_holder.blank?
    if guide && source_url.blank?
      rights_holder_name ||= guide.user.name unless guide.user.name.blank?
      rights_holder_name ||= guide.user.login
    end
    rights_holder_name ||= I18n.t(:unknown)
  end

  def self.new_from_eol_data_object(data_object)
    thumb_url = data_object.at('thumbnailURL').try(:content)
    p = /_\d+_\d+\.(\w+)$/
    original_url = if thumb_url && thumb_url.match(p)
      thumb_url.sub(p, "_orig.\\1")
    else
      data_object.at('mediaURL').try(:content)
    end
    medium_url = if thumb_url && thumb_url.match(p)
      thumb_url.sub(p, "_580_360.\\1")
    else
      original_url
    end
    rights_holder = data_object.at('rightsHolder').try(:content)
    rights_holder ||= data_object.at('agent[role=compiler]').try(:content)
    rights_holder ||= data_object.at('agent[role=author]').try(:content)
    gr = GuideRange.new(
      :rights_holder => rights_holder,
      :thumb_url => thumb_url,
      :medium_url => medium_url,
      :original_url => original_url
    )
    gr.license = case data_object.at('license').to_s
    when /\/by\// then Observation::CC_BY
    when /\/by-nc\// then Observation::CC_BY_NC
    when /\/by-sa\// then Observation::CC_BY_SA
    when /\/by-nd\// then Observation::CC_BY_ND
    when /\/by-nc-sa\// then Observation::CC_BY_NC_SA
    when /\/by-nc-nd\// then Observation::CC_BY_NC_ND
    when /\/publicdomain\// then Photo::PD_CODE
    else
      data_object.at('license').to_s
    end
    gr.source_url = if (verson_id = data_object.at('dataObjectVersionID').try(:content))
      "http://eol.org/data_objects/#{verson_id}"
    elsif data_object.at('source').to_s =~ /http/
      data_object.at('source').to_s
    end
    gr
  end

  def thumb_url
    if read_attribute(:thumb_url).blank?
      file? ? file.url(:thumb) : nil
    else
      read_attribute(:thumb_url)
    end
  end

  def small_url
    file.url(:small) if file?
  end

  def medium_url
    if read_attribute(:medium_url).blank?
      file? ? file.url(:medium) : nil
    else
      read_attribute(:medium_url)
    end
  end

  def large_url
    file.url(:large) if file?
  end

  def original_url
    if read_attribute(:original_url).blank?
      file? ? file.url(:original) : nil
    else
      read_attribute(:original_url)
    end
  end

  def reusable?(options = {})
    user_id = if options[:user]
      options[:user].is_a?(User) ? options[:user].id : options[:user]
    end
    return true if user_id && guide.guide_users.map(&:user_id).include?(user_id)
    !license.blank?
  end

end
