#encoding: utf-8
class GuideTaxon < ActiveRecord::Base
  attr_accessor :html
  belongs_to :guide, :inverse_of => :guide_taxa
  belongs_to :taxon, :inverse_of => :guide_taxa
  has_one :user, :through => :guide
  has_many :guide_sections, :inverse_of => :guide_taxon, :dependent => :delete_all
  has_many :guide_photos, :inverse_of => :guide_taxon, :dependent => :delete_all
  has_many :guide_ranges, :inverse_of => :guide_taxon, :dependent => :delete_all
  has_many :photos, :through => :guide_photos
  accepts_nested_attributes_for :guide_sections, :allow_destroy => true
  accepts_nested_attributes_for :guide_photos, :allow_destroy => true
  accepts_nested_attributes_for :guide_ranges, :allow_destroy => true

  validates_presence_of :guide, :taxon
  validate :within_count_limit, :on => :create
  validates_uniqueness_of :name, :scope => :guide_id, :allow_blank => true, :message => "has already been added to this guide"

  before_create :set_names_from_taxon
  before_create :set_default_photos
  before_create :set_default_section
  after_create :set_guide_taxon
  after_destroy :set_guide_taxon
  after_save {|r| r.guide.expire_caches(:check_ngz => true)}
  after_destroy {|r| r.guide.expire_caches(:check_ngz => true)}

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
    scope = GuideTaxon.all
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

  def within_count_limit
    errors.add(:base, :guide_has_too_many_taxa) if guide && guide.guide_taxa.count >= 500
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

  def set_default_photos(options = {})
    return true if taxon.blank?
    return true if taxon.photos.blank?
    max = options[:max]
    max = 1 if max.blank? || max > 10
    taxon.taxon_photos.includes(:photo).sort_by{|tp| tp.position || tp.id}.each do |tp|
      next unless tp.photo.open_licensed?
      break if max && self.guide_photos.size >= max
      self.guide_photos.build(:photo => tp.photo) if tp.photo && self.guide_photos.detect{|gp| gp.photo_id == tp.photo_id}.blank?
    end
    self.guide_photos.each_with_index do |tp,i|
      self.guide_photos[guide_photos.index(tp)].position = i+1
    end
    true
  end

  def set_default_section(options = {})
    return true if taxon.blank?
    return true unless guide_sections.blank? || options[:force]
    return true if taxon.wikipedia_summary.blank?
    if options[:force] && (gs = guide_sections.detect{|gs| gs.rights_holder == "Wikipedia"})
      self.guide_sections[guide_sections.index(gs)].description = taxon.wikipedia_summary
    else
      self.guide_sections.build(
        :title => "Summary", 
        :description => taxon.wikipedia_summary,
        :rights_holder => "Wikipedia",
        :license => Observation::CC_BY_SA,
        :source_url => TaxonDescribers::Wikipedia.page_url(taxon)
      )
    end
    true
  end

  def set_guide_taxon
    return true if Delayed::Job.where("handler LIKE '%Guide\n%id: ''#{guide_id}''\n%set_taxon%'").exists?
    self.guide.delay(:priority => USER_INTEGRITY_PRIORITY).set_taxon
    true
  end

  def sync_site_content(options = {})
    set_names_from_taxon if options[:names]
    set_default_photos(:max => 5) if options[:photos]
    set_default_section(:force => true) if options[:summary]
    save!
  end

  def sync_eol(options = {})
    if guide.source_url && guide.source_url =~ /eol.org\/collections\/\d+/
      options
    end
    return unless page = get_eol_page(options)
    options[:replace] = options[:replace].yesish?
    options[:subjects] = [options[:subjects]].flatten.reject {|s| s.blank?}
    if options[:replace] || self.name.blank?
      name = page.at('scientificName').content
      name = TaxonName.strip_author(Taxon.remove_rank_from_name(FakeView.strip_tags(name)))
      self.name ||= name
    end
    if options[:replace] || self.display_name.blank?
      common_names = page.search('commonName')
      locale = options[:locale]
      locale = guide.user.locale if locale.blank?
      locale = I18n.locale if locale.blank?
      lang = locale.to_s.split('-').first
      common_name = common_names.detect{|cn| cn['lang'] == lang && cn['eol_preferred'] == "true"}
      common_name ||= common_names.detect{|cn| cn['lang'] == lang}
      common_name ||= common_names.detect{|cn| cn['eol_preferred'] == "true"}
      if common_name && !common_name.inner_text.blank?
        self.display_name = common_name.inner_text
      end
    end
    sync_eol_photos(options.merge(:page => page)) if options[:photos].yesish?
    sync_eol_ranges(options.merge(:page => page)) if options[:ranges].yesish?
    Rails.logger.debug "[DEBUG] options[:subjects]: #{options[:subjects].inspect}"
    sync_eol_sections(options.merge(:page => page)) if options[:sections].yesish? || options[:overview].yesish?
    save!
  end

  def sync_eol_photos(options = {})
    return unless page = get_eol_page(options)
    img_data_objects = page.search('dataObject').select{|data_object| 
      data_object.at('dataType').to_s =~ /StillImage/ && data_object.at('dataSubtype').to_s !~ /Map/
    }
    guide_photos.destroy_all if options[:replace].yesish?
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
    guide_ranges.destroy_all if options[:replace].yesish?
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

    guide_sections.destroy_all if options[:replace].yesish?
    max_pos = guide_sections.calculate(:maximum, :position) || 0

    data_objects = if subjects.blank? || options[:overview] == "true"
      [data_objects.first]
    else
      unique_data_objects = ActiveSupport::OrderedHash.new
      data_objects.each do |data_object| 
        data_object_subject = if (s = data_object.at('subject'))
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
      :common_names => true,
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

    if !page && eol_page_id
      page = eol.page(eol_page_id, page_request_params)
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

  def add_color_tags
    return unless taxon
    tags = tag_list + taxon.colors.map{|c| "color=#{c.value.downcase}"}
    update_attributes(:tag_list => tags.uniq)
  end

  def add_rank_tag(rank, options = {})
    return unless taxon
    lexicon = options[:lexicon] || TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
    lexicon = TaxonName::LEXICONS[lexicon.to_sym] if TaxonName::LEXICONS[lexicon.to_sym]
    rank_taxon = taxon.send("find_#{rank}") rescue nil
    return unless rank_taxon
    name = if lexicon == TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
      rank_taxon.name
    elsif tn = rank_taxon.taxon_names.sort_by(&:id).detect{|tn| tn.lexicon == lexicon}
      tn.name
    end
    return if name.blank?
    tags = tag_list + ["taxonomy:#{rank}=#{name}"]
    update_attributes(:tag_list => tags.uniq)
  end

  def eol_page_id
    @eol_page_id ||= source_identifier.to_s[/eol.org\/pages\/(\d+)/, 1]
  end

  def reuse(options = {})
    attrs = attributes.reject{|k,v| %(id guide_id created_at updated_at).include?(k.to_s)}
    gt = GuideTaxon.new(attrs)
    [:guide_photos, :guide_ranges, :guide_sections].each do |relat|
      send(relat).sort_by{|r| r.position || r.id }.each do |record|
        if record.reusable?(options)
          reusable_record = record.respond_to?(:reuse) ? record.reuse : record
          attrs = reusable_record.attributes.reject{|k,v| %(id created_at updated_at).include?(k.to_s)}
          gt.send(relat).build(attrs)
        end
      end
    end
    gt
  end

  def self.new_from_eol_collection_item(item, options = {})
    name = item.at('name').inner_text.strip
    name = TaxonName.strip_author(Taxon.remove_rank_from_name(FakeView.strip_tags(name)))
    object_id = item.at('object_id').inner_text
    options[:source_identifier] ||= "http://eol.org/pages/#{object_id}"
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
