class GuideRange < ActiveRecord::Base
  attr_accessible :guide_taxon_id, :thumb_url, :medium_url, :original_url, :rights_holder, :license, :source_id, :source_url
  belongs_to :guide_taxon, :inverse_of => :guide_ranges
  has_one :guide, :through => :guide_taxon
  after_save {|r| r.guide.expire_caches}
  after_destroy {|r| r.guide.expire_caches}

  def to_s
    "<GuideRange #{id}>"
  end

  def attribution
    return I18n.t(:public_domain) if license == Photo::PD_CODE
    rights_holder_name ||= rights_holder unless rights_holder.blank?
    if guide && source_url.blank?
      rights_holder_name ||= guide.user.name unless guide.user.name.blank?
      rights_holder_name ||= guide.user.login
    end
    rights_holder_name ||= I18n.t(:unknown)
    if license.blank?
      I18n.t('copyright.all_rights_reserved', :name => rights_holder_name)
    else
      I18n.t('copyright.some_rights_reserved_by', :name => rights_holder_name, :license_short => license)
    end
  end

  def self.new_from_eol_data_object(data_object)
    gr = GuideRange.new(
      :rights_holder => data_object.at('rightsHolder').try(:content) || data_object.at('agent[role=compiler]').try(:content),
      :thumb_url => data_object.at('thumbnailURL').try(:content),
      :medium_url => data_object.at('mediaURL').try(:content),
      :original_url => data_object.at('mediaURL').try(:content)
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
end
