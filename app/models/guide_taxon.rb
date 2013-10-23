#encoding: utf-8
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
  after_save {|r| r.guide.expire_caches(:check_ngz => true)}
  after_destroy {|r| r.guide.expire_caches(:check_ngz => true)}

  validates_uniqueness_of :taxon_id, :scope => :guide_id, :allow_blank => true, :message => "has already been added to this guide"

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
    self.guide_photos.build(:photo => taxon.taxon_photos.first.try(:photo))    
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

  def sync_eol(options = {})
    return unless page = get_eol_page(options)
    name = page.at('scientificName').content
    name = TaxonName.strip_author(Taxon.remove_rank_from_name(FakeView.strip_tags(name)))
    self.name ||= name
    common_names = page.search('commonName')
    lang = (options[:locale] || guide.user.locale || I18n.locale).to_s.split('-').first
    common_name = common_names.detect{|cn| cn['lang'] == lang && cn['eol_preferred'] == "true"}
    common_name ||= common_names.detect{|cn| cn['lang'] == lang}
    common_name ||= common_names.detect{|cn| cn['eol_preferred'] == "true"}
    if common_name && !common_name.inner_text.blank?
      self.display_name = common_name.inner_text
    end
    sync_eol_photos(options.merge(:page => page)) if options[:photos]
    sync_eol_ranges(options.merge(:page => page)) if options[:ranges]
    sync_eol_sections(options.merge(:page => page)) if [true, 1, "true", "1"].include?(options[:overview]) || !options[:subjects].blank?
    save!
  end

  def sync_eol_photos(options = {})
    return unless page = get_eol_page(options)
    img_data_objects = page.search('dataObject').select{|data_object| 
      data_object.at('dataType').to_s =~ /StillImage/ && data_object.at('dataSubtype').to_s !~ /Map/
    }
    max_pos = guide_photos.calculate(:maximum, :position) || 0
    img_data_objects[0..5].each do |img_data_object|
      p = if (data_object_id = img_data_object.at('dataObjectID').try(:content))
        EolPhoto.find_by_native_photo_id(data_object_id)
      end
      p ||= EolPhoto.new_from_api_response(img_data_object)
      if !p.blank? && self.guide_photos.detect{|gp| gp.photo_id && gp.photo_id == p.id}.blank?
        self.guide_photos.build(:photo => p, :position => (max_pos += 1))
      end
    end
  end

  def sync_eol_ranges(options = {})
    return unless page = get_eol_page(options)
    map_data_object = page.search('dataObject').detect{|data_object| data_object.at('dataSubtype').to_s =~ /Map/ }
    if map_data_object
      gr = GuideRange.new_from_eol_data_object(map_data_object)
      unless guide_ranges.where(:source_url => gr.source_url).exists?
        self.guide_ranges[self.guide_ranges.size] = gr
      end
    end
  end

  def sync_eol_sections(options = {})
    return unless page = get_eol_page(options)
    subjects = (options[:subjects] || []).select{|s| !s.blank?}

    xpath = <<-XPATH
      //dataObject[
        descendant::dataType[text()='http://purl.org/dc/dcmitype/Text']
        and descendant::subject
      ]
    XPATH
    locale = (options[:locale] || guide.user.locale || I18n.locale).to_s
    data_objects = page.xpath(xpath).reject do |data_object|
      data_object.at('language') && locale !~ /^#{data_object.at('language').content}/
    end

    max_pos = guide_sections.calculate(:maximum, :position) || 0

    data_objects = if subjects.blank? || options[:overview] == "true"
      [data_objects.first]
    else
      unique_data_objects = ActiveSupport::OrderedHash.new
      data_objects.each do |data_object| 
        data_object_subject = if s = data_object.at('subject')
          s.content.split('#').last
        end
        if subjects.include?(data_object_subject)
          unique_data_objects[data_object_subject] ||= data_object
        end
      end
      unique_data_objects.values
    end

    data_objects.compact.each do |data_object|
      gs = GuideSection.new_from_eol_data_object(data_object)
      gs.position = (max_pos += 1)
      if gs && !guide_sections.where(:source_url => gs.source_url).exists?
        gs.modified_on_create = false
        self.guide_sections[self.guide_sections.size] = gs
      end
    end
  end

  def get_eol_page(options = {})
    eol = options[:eol] || EolService.new(:timeout => 30, :debug => Rails.env.development?)
    page = options[:page]
    collection = options[:collection]
    subjects = (options[:subjects] || []).select{|t| !t.blank?}
    page_request_params = {
      :images => 5, 
      :maps => 5, 
      :text => subjects.size == 0 ? 5 : subjects.size * 5,
      :details => true}
    page_request_params[:subjects] = if subjects.blank?
      "overview"
    else
      subjects.join('|')
    end

    if !page && collection
      item = collection.search("item").detect do |item|
        item.at('object_type').content == "TaxonConcept" && item.at('name').content.downcase =~ /#{name.downcase}/
      end
      page = eol.page(item.at('object_id').content, page_request_params) if item
    end

    unless page
      search_results = eol.search(name, :exact => true)
      if result = search_results.search('entry').first #detect{|e| e.at('title').to_s.downcase =~ /#{name.downcase}/}
        page = eol.page(result.at('id').content, page_request_params)
      end
    end

    if page
      page.remove_namespaces! if page.respond_to?(:remove_namespaces!)
      return page
    end
  end

  def self.new_from_eol_collection_item(item, options = {})
    name = item.at('name').inner_text.strip
    name = TaxonName.strip_author(Taxon.remove_rank_from_name(FakeView.strip_tags(name)))
    object_id = item.at('object_id').inner_text
    taxon = Taxon.single_taxon_for_name(name)
    taxon ||= Taxon.find_by_name(name)
    rank = case name.split.size
    when 3 then "subspecies"
    when 2 then "species"
    end
    gt = GuideTaxon.new(options)
    gt.name = name
    if taxon && taxon.valid?
      gt.taxon = taxon 
    else
      gt.display_name = name
    end
    gt
  end
end
