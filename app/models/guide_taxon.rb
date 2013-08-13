class GuideTaxon < ActiveRecord::Base
  attr_accessor :html
  attr_accessible :display_name, :guide, :guide_id, :name, :taxon_id, :taxon, :guide_photos_attributes, 
    :guide_sections_attributes, :guide_ranges_attributes, :html, :position, :tag_list
  belongs_to :guide, :inverse_of => :guide_taxa
  belongs_to :taxon, :inverse_of => :guide_taxa
  has_many :guide_sections, :inverse_of => :guide_taxon, :dependent => :destroy
  has_many :guide_photos, :inverse_of => :guide_taxon, :dependent => :destroy
  has_many :guide_ranges, :inverse_of => :guide_taxon, :dependent => :destroy
  has_many :photos, :through => :guide_photos
  accepts_nested_attributes_for :guide_sections, :allow_destroy => true
  accepts_nested_attributes_for :guide_photos, :allow_destroy => true
  accepts_nested_attributes_for :guide_ranges, :allow_destroy => true
  before_save :set_names_from_taxon
  before_create :set_default_photo
  before_create :set_default_section
  after_create :set_guide_taxon
  after_destroy :set_guide_taxon
  after_save {|r| r.guide.expire_caches}
  after_destroy {|r| r.guide.expire_caches}

  validates_uniqueness_of :taxon_id, :scope => :guide_id, :message => "has already been added to this guide"

  acts_as_taggable

  SORTS = %w(default alphadisplay alphaname)
  SORTS.each do |s|
    const_set "#{s.parameterize.underscore.upcase}_SORT", s
  end

  scope :sorted_by, lambda {|sort|
    case sort
    when ALPHANAME_SORT
      order("guide_taxa.name")
    when ALPHADISPLAY_SORT
      order("guide_taxa.display_name")
    else
      order("guide_taxa.position")
    end
  }

  scope :in_taxon, lambda {|taxon| 
    taxon = Taxon.find_by_id(taxon.to_i) unless taxon.is_a? Taxon
    return where("1 = 2") unless taxon
    c = taxon.descendant_conditions
    c[0] = "taxa.id = #{taxon.id} OR #{c[0]}"
    joins(:taxon).where(c)
  }

  scope :tagged, lambda {|tags|
    if tags.is_a?(String)
      tags = [tags]
    end
    scope = scoped
    tags.each_with_index do |tag, i|
      taggings_join_name = "_taggings#{i}"
      scope = scope.joins("LEFT OUTER JOIN taggings #{taggings_join_name} ON #{taggings_join_name}.taggable_type = 'GuideTaxon' AND #{taggings_join_name}.taggable_id = guide_taxa.id")
      tags_join_name = "_tags#{i}"
      scope = scope.joins("LEFT OUTER JOIN tags #{tags_join_name} ON #{tags_join_name}.id = #{taggings_join_name}.tag_id").where("#{tags_join_name}.name = ?", tag)
    end
    scope
  }

  scope :dbsearch, lambda {|q| where("guide_taxa.name ILIKE ? OR guide_taxa.display_name ILIKE ?", "%#{q}%", "%#{q}%")}

  def to_s
    "<GuideTaxon #{id} guide_id: #{guide_id}, name: #{name}, taxon_id: #{taxon_id}>"
  end

  def default_guide_photo
    guide_photos.sort_by(&:position).first
  end

  def set_names_from_taxon
    return true unless taxon
    self.name = taxon.name if name.blank?
    self.display_name = taxon.default_name.name if display_name.blank?
    true
  end

  def set_default_photo
    return true unless guide_photos.blank?
    return true if taxon.blank?
    return true if taxon.photos.blank?
    self.guide_photos.build(:photo => taxon.photos.first)    
    true
  end

  def set_default_section
    return true if taxon.blank?
    return true unless guide_sections.blank?
    return true if taxon.wikipedia_summary.blank?
    self.guide_sections.build(
      :title => "Summary", 
      :description => taxon.wikipedia_summary,
      :rights_holder => "Wikipedia",
      :license => Observation::CC_BY_SA,
      :source_url => TaxonDescribers::Wikipedia.page_url(taxon)
    )
    true
  end

  def set_guide_taxon
    return true if Delayed::Job.where("handler LIKE '%Guide\n%id: ''#{guide_id}''\n%set_taxon%'").exists?
    self.guide.delay(:priority => USER_INTEGRITY_PRIORITY).set_taxon
    true
  end

  def self.new_from_eol_collection_item(item, options = {})
    name = item.at('name').inner_text.strip
    name = TaxonName.strip_author(Taxon.remove_rank_from_name(FakeView.strip_tags(name)))
    object_id = item.at('object_id').inner_text

    # Fetching a page for each taxon is prohibitively slow. Let's revisit this if EOL decides to include this data in the collection response.
    # page = EolService.page(object_id, :common_names => true, :images => 1, :details => true)
    # page.remove_namespaces! if page.respond_to?(:remove_namespaces!)
    # common_names = page.search('commonName')
    # lang = I18n.locale.to_s.split('-').first
    # common_name = common_names.detect{|cn| cn['lang'] == lang && cn['eol_preferred'] == "true"}
    # common_name ||= common_names.detect{|cn| cn['lang'] == lang}
    # common_name ||= common_names.detect{|cn| cn['eol_preferred'] == "true"}
    # img_data_object = page.search('dataObject').detect{|data_object| data_object.at('dataType').to_s =~ /StillImage/ }
    taxon = Taxon.single_taxon_for_name(name)
    taxon ||= Taxon.find_by_name(name)
    rank = case name.split.size
    when 3 then "subspecies"
    when 2 then "species"
    end
    gt = GuideTaxon.new(options)
    
    if taxon && taxon.valid?
      gt.taxon = taxon 
    else
      gt.name = name
      gt.display_name = name
    end
    # if common_name && !common_name.inner_text.blank?
    #   gt.display_name = common_name.inner_text
    # end
    # I think this gets into copyright territory
    # if (annotation = item.at('annotation')) && !annotation.inner_text.blank?
    #   gt.guide_sections.build(:title => "Annotation", :description => annotation.inner_text)
    # end
    # if img_data_object
    #   p = if (data_object_id = img_data_object.at('dataObjectId').try(:content))
    #     EolPhoto.find_by_native_photo_id(data_object_id)
    #   end
    #   p ||= EolPhoto.new_from_api_response(img_data_object)
    #   gp = gt.guide_photos.build(:photo => p) unless p.blank?
    # end
    # Rails.logger.debug "[DEBUG] gt.errors: #{gt.errors.full_messages.to_sentence}" unless gt.valid?
    gt
  end
end
