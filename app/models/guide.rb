class Guide < ActiveRecord::Base
  attr_accessible :description, :latitude, :longitude, :place_id,
    :published_at, :title, :user_id, :icon, :license, :icon_file_name,
    :icon_content_type, :icon_file_size, :icon_updated_at, :zoom_level, 
    :map_type, :taxon, :taxon_id, :source_url
  belongs_to :user, :inverse_of => :guides
  belongs_to :place, :inverse_of => :guides
  belongs_to :taxon, :inverse_of => :guides
  has_many :guide_taxa, :inverse_of => :guide, :dependent => :destroy
  
  has_attached_file :icon, 
    :styles => { :medium => "500x500>", :thumb => "48x48#", :mini => "16x16#", :span2 => "70x70#" },
    :default_url => "/attachment_defaults/:class/:style.png",
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :s3_host_alias => CONFIG.s3_bucket,
    :bucket => CONFIG.s3_bucket,
    :path => "guides/:id-:style.:extension",
    :url => ":s3_alias_url"
  
  validates_attachment_content_type :icon, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/], 
    :message => "must be JPG, PNG, or GIF"
  validates_length_of :title, :in => 3..255

  after_update :expire_caches
  after_destroy :expire_caches
  before_create :set_defaults_from_source_url
  after_create :add_taxa_from_source_url

  scope :dbsearch, lambda {|q| where("guides.title ILIKE ?", "%#{q}%")}

  def import_taxa(options = {})
    if options[:eol_collection_url]
      return add_taxa_from_eol_collection(options[:eol_collection_url])
    end
    return if options[:place_id].blank? && options[:list_id].blank? && options[:taxon_id].blank?
    scope = if !options[:place_id].blank?
      Taxon.from_place(options[:place_id]).scoped
    elsif !options[:list_id].blank?
      Taxon.on_list(options[:list_id]).scoped
    else
      Taxon.scoped
    end
    if t = Taxon.find_by_id(options[:taxon_id])
      scope = scope.descendants_of(t)
    end
    taxa = []
    scope.includes(:taxon_photos, :taxon_descriptions).find_each do |taxon|
      gt = self.guide_taxa.build(
        :taxon_id => taxon.id,
        :name => taxon.name,
        :display_name => taxon.default_name.name
      )
      unless gt.save
        Rails.logger.error "[ERROR #{Time.now}] Failed to save #{gt}: #{gt.errors.full_messages.to_sentence}"
      end
      taxa << gt
    end
    taxa
  end

  def editable_by?(user)
    self.user_id == user.try(:id)
  end

  def set_taxon
    ancestry_counts = log_timer do
      Taxon.joins(:guide_taxa).where("guide_taxa.guide_id = ?", id).group(:ancestry).count
    end
    ancestries = ancestry_counts.map{|a,c| a.to_s.split('/')}.sort_by(&:size).compact
    if ancestries.blank?
      Guide.update_all({:taxon_id => nil}, ["id = ?", id])
      return
    end
    
    width = ancestries.last.size
    matrix = ancestries.map do |a|
      a + ([nil]*(width-a.size))
    end

    # start at the right col (lowest rank), look for the first occurrence of
    # consensus within a rank
    consensus_taxon_id = nil
    width.downto(0) do |c|
      column_taxon_ids = matrix.map{|ancestry| ancestry[c]}
      if column_taxon_ids.uniq.size == 1 && !column_taxon_ids.first.blank?
        consensus_taxon_id = column_taxon_ids.first
        break
      end
    end

    Guide.update_all({:taxon_id => consensus_taxon_id}, ["id = ?", id])
  end

  def expire_caches
    ctrl = ActionController::Base.new
    ctrl.expire_page("/guides/#{id}.pdf")
    GuidesController::PDF_LAYOUTS.each do |l|
      ctrl.expire_page("/guides/#{id}.#{l}.pdf")
    end
    true
  end

  def reorder_by_taxonomy
    gts = self.guide_taxa.includes(:taxon).all
    indexed_guide_taxa = gts.index_by(&:taxon_id)
    taxa = gts.map(&:taxon).compact
    guide_taxa_without_taxa = gts.select{|gt| gt.taxon.blank?}
    ordered_taxa = guide_taxa_without_taxa + Taxon.sort_by_ancestry(taxa) {|t1,t2| t1.name <=> t2.name}
    ordered_taxa.each_with_index do |t,i|
      gt = indexed_guide_taxa[t.id]
      next unless gt
      gt.update_attribute(:position, i+1)
    end
  end

  def set_defaults_from_source_url(options = {})
    return true if source_url.blank?
    if source_url =~ /eol.org\/collections\/\d+/
      set_defaults_from_eol_collection(source_url, options)
    end
    true    
  end

  def set_defaults_from_eol_collection(collection_url, options = {})
    return unless collection_id = collection_url[/\/(\d+)(\.\w+)?$/, 1]
    eol = EolService.new(:timeout => 30)
    c = eol.collections(collection_id)
    self.title ||= c.at('name').inner_text
    self.description ||= c.at('description').inner_text
    if !self.icon.present? && !options[:skip_icon] && (logo_url = c.at('logo_url').inner_text) && !logo_url.blank?
      logo_url.strip!
      io = open(URI.parse(logo_url))
      self.icon = (io.base_uri.path.split('/').last.blank? ? nil : io)
    end
  end

  def add_taxa_from_source_url
    return if source_url.blank?
    add_taxa_from_eol_collection(source_url)
  end

  def add_taxa_from_eol_collection(collection_url)
    return unless collection_id = collection_url[/\/(\d+)(\.\w+)?$/, 1]
    eol = EolService.new(:timeout => 30)
    c = eol.collections(collection_id, :per_page => 500, :filter => "taxa", :sort_by => "sort_field")
    saved = 0
    errors = []
    eol_source = Source.find_by_in_text('EOL')
    eol_source ||= Source.create(
      :in_text => 'EOL',
      :citation => "Encyclopedia of Life. Available from http://www.eol.org.",
      :url => "http://www.eol.org",
      :title => 'Encyclopedia of Life'
    )
    guide_taxa = []
    c.search("item").each_with_index do |item,i|
      gt = GuideTaxon.new_from_eol_collection_item(item, :position => i+1, :guide => self)
      if gt.save
        saved += 1
      else
        errors << gt.errors.full_messages.to_sentence
      end
      guide_taxa << gt
    end
    Rails.logger.debug "[DEBUG] #{self} add_taxa_from_eol_collection, #{saved} saved, #{errors.size} errors"
    guide_taxa
  end

  def recent_tags
    tag_sql = <<-SQL
      SELECT DISTINCT ON (tags.name) tags.*, taggings.id AS taggings_id
      FROM tags
        JOIN taggings ON taggings.tag_id = tags.id
        JOIN guide_taxa ON guide_taxa.id = taggings.taggable_id
      WHERE
        taggable_type = 'GuideTaxon' AND
        guide_taxa.guide_id = #{id}
    SQL
    Tag.find_by_sql("SELECT * FROM (#{tag_sql}) AS guide_tags ORDER BY guide_tags.taggings_id DESC LIMIT 20").map(&:name).sort_by(&:downcase)
  end
end
