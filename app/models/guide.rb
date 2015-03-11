class Guide < ActiveRecord::Base
  acts_as_spammable :fields => [ :title, :description ]
  belongs_to :user, :inverse_of => :guides
  belongs_to :place, :inverse_of => :guides
  belongs_to :taxon, :inverse_of => :guides
  has_many :guide_taxa, :inverse_of => :guide, :dependent => :destroy
  has_many :guide_users, :inverse_of => :guide, :dependent => :delete_all

  accepts_nested_attributes_for :guide_users, :allow_destroy => true

  attr_accessor :publish
  
  has_attached_file :icon, 
    :styles => { :medium => "500x500>", :thumb => "48x48#", :mini => "16x16#", :span2 => "70x70#", :small_square => "200x200#" },
    :default_url => "/attachment_defaults/:class/icons/:style.png",
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :s3_host_alias => CONFIG.s3_bucket,
    :bucket => CONFIG.s3_bucket,
    :path => "guides/:id-:style.:extension",
    :url => ":s3_alias_url"

  if Rails.env.production?
    has_attached_file :ngz,
      :storage => :s3,
      :s3_credentials => "#{Rails.root}/config/s3.yml",
      :s3_host_alias => CONFIG.s3_bucket,
      :bucket => CONFIG.s3_bucket,
      :path => "guides/:id.ngz",
      :url => ":s3_alias_url",
      :default_url => ""
  else
    has_attached_file :ngz,
      :path => ":rails_root/public/attachments/:class/:id.ngz",
      :url => "#{ CONFIG.attachments_host }/attachments/:class/:id.ngz",
      :default_url => ""
  end

  before_validation :set_published_at
  
  validates_attachment_content_type :icon, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/], 
    :message => "must be JPG, PNG, or GIF"
  validates_length_of :title, :in => 3..255
  validate :must_have_some_guide_taxa_to_publish

  before_save :generate_ngz_if_necessary
  after_update :expire_caches
  after_destroy :expire_caches
  before_create :set_defaults_from_source_url,
                :create_guide_user
  after_create :add_taxa_from_source_url


  scope :dbsearch, lambda {|q| where("guides.title ILIKE ? OR guides.description ILIKE ?", "%#{q}%", "%#{q}%")}
  scope :near_point, lambda {|latitude, longitude|
    latitude = latitude.to_f
    longitude = longitude.to_f
    where("ST_Distance(ST_Point(guides.longitude, guides.latitude), ST_Point(#{longitude}, #{latitude})) < 5").
    order("ST_Distance(ST_Point(guides.longitude, guides.latitude), ST_Point(#{longitude}, #{latitude}))")
  }
  scope :published, -> { where("published_at IS NOT NULL") }

  def to_s
    "<Guide #{id} #{title}>"
  end

  def import_taxa(options = {})
    if options[:eol_collection_url]
      return add_taxa_from_eol_collection(options[:eol_collection_url])
    end
    unless options[:names].blank?
      return add_taxa_from_names(options[:names])
    end
    return if options[:place_id].blank? && options[:list_id].blank? && options[:taxon_id].blank?
    scope = if !options[:place_id].blank?
      Taxon.from_place(options[:place_id])
    elsif !options[:list_id].blank?
      Taxon.on_list(options[:list_id])
    else
      Taxon.all
    end
    if t = Taxon.find_by_id(options[:taxon_id])
      scope = scope.descendants_of(t)
    end
    scope = scope.of_rank(options[:rank]) if Taxon::RANKS.include?(options[:rank])
    guide_taxa = []
    scope.includes(:taxon_photos, :taxon_descriptions).find_each do |taxon|
      gt = self.guide_taxa.build(
        :taxon_id => taxon.id,
        :name => taxon.name,
        :display_name => taxon.default_name.name
      )
      unless gt.save
        Rails.logger.error "[ERROR #{Time.now}] Failed to save #{gt}: #{gt.errors.full_messages.to_sentence}"
      end
      guide_taxa << gt
    end
    guide_taxa
  end

  def editable_by?(user)
    user_id = user.is_a?(User) ? user.id : user
    return false if user_id.blank?
    guide_users.detect{|gu| gu.user_id == user_id}
  end

  def set_taxon
    ancestry_counts = Taxon.joins(:guide_taxa).where("guide_taxa.guide_id = ?", id).group(:ancestry).count
    ancestries = ancestry_counts.map{|a,c| a.to_s.split('/')}.sort_by(&:size).compact
    if ancestries.blank?
      Guide.where(id: id).update_all(taxon_id: nil)
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

    Guide.where(id: id).update_all(taxon_id: consensus_taxon_id)
  end

  def set_published_at
    if publish == "publish"
      self.published_at = Time.now
    elsif publish == "unpublish"
      self.published_at = nil
    end
  end

  def expire_caches(options = {})
    ctrl = ActionController::Base.new
    ctrl.expire_page("/guides/#{id}.pdf") rescue nil
    ctrl.expire_page("/guides/#{id}.xml") rescue nil
    GuidesController::PDF_LAYOUTS.each do |l|
      ctrl.expire_page("/guides/#{id}.#{l}.pdf") rescue nil
    end
    ctrl.expire_page("/guides/#{to_param}.ngz") rescue nil
    if options[:check_ngz]
      if downloadable?
        generate_ngz_later
      else
        update_attributes(:ngz => nil)
      end
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

  def create_guide_user
    self.guide_users.build(:user_id => user_id)
  end

  def add_taxa_from_eol_collection(collection_url)
    return unless collection_id = collection_url[/\/(\d+)(\.\w+)?$/, 1]
    eol = EolService.new(:timeout => 30, :debug => Rails.env.development?)
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
      existing = self.guide_taxa.where(:source_identifier => gt.source_identifier).first unless gt.source_identifier.blank?
      if existing
        %w(name display_name source_identifier).each do |a|
          existing.send("#{a}=", gt.send(a))
        end
        if existing.save
          saved += 1
        else
          errors << gt.errors.full_messages.to_sentence
        end
      else
        if gt.save
          saved += 1
        else
          errors << gt.errors.full_messages.to_sentence
        end
        guide_taxa << gt
      end
    end
    guide_taxa
  end

  def add_taxa_from_names(names)
    if names.is_a?(String)
      names = names.split("\n").compact.map(&:strip)
    end
    guide_taxa = []
    names[0..500].each do |name|
      name, display_name = name.split(',')
      gt = if taxon = Taxon.single_taxon_for_name(name)
        default_name = taxon.default_name.name
        display_name = if name.downcase == default_name.downcase
          display_name || default_name
        elsif name.downcase == taxon.name.downcase
          display_name
        else
          display_name || name
        end
        self.guide_taxa.build(
          :taxon_id => taxon.id,
          :name => taxon.name,
          :display_name => display_name
        )
      else
        self.guide_taxa.build(:name => name, :display_name => display_name)
      end
      unless gt.save
        Rails.logger.error "[ERROR #{Time.now}] Failed to save #{gt}: #{gt.errors.full_messages.to_sentence}"
      end
      guide_taxa << gt
    end
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
    ActsAsTaggableOn::Tag.find_by_sql("SELECT * FROM (#{tag_sql}) AS guide_tags ORDER BY guide_tags.taggings_id DESC LIMIT 20").map(&:name).sort_by(&:downcase)
  end

  def tags
    tag_sql = <<-SQL
      SELECT DISTINCT ON (tags.name) tags.*, taggings.id AS taggings_id
      FROM tags
        JOIN taggings ON taggings.tag_id = tags.id
        JOIN guide_taxa ON guide_taxa.id = taggings.taggable_id
      WHERE
        taggable_type = 'GuideTaxon' AND
        guide_taxa.guide_id = #{id}
    SQL
    ActsAsTaggableOn::Tag.find_by_sql("SELECT * FROM (#{tag_sql}) AS guide_tags").map(&:name).sort_by(&:downcase)
  end

  def ngz_url
    return nil unless downloadable?
    return nil if ngz.url.blank?
    FakeView.uri_join(FakeView.root_url, ngz.url).to_s
  end

  def ngz_size
    ngz.size
  end

  def generate_ngz_if_necessary
    return nil unless %w(title description downloadable published_at).detect{|a| send("#{a}_changed?")}
    if downloadable?
      generate_ngz_later
    else
      Delayed::Job.where("handler LIKE '%id: ''#{id}''%generate_ngz%'").destroy_all
      self.ngz = nil
    end
    true
  end

  def generate_ngz_later
    return if Delayed::Job.where("handler LIKE '%id: ''#{id}''%generate_ngz%'").exists?
    delay(:priority => USER_INTEGRITY_PRIORITY).generate_ngz
  end

  def generate_ngz_cache_key
    "gen_ngz_#{id}"
  end

  def generate_ngz(options = {})
    zip_path = to_ngz
    open(zip_path) do |f|
      unless update_attributes(:ngz => f)
        Rails.logger.error "[ERROR #{Time.now}] Failed to save NGZ attachment for guide #{id}: #{errors.full_messages.to_sentence}"
      end
    end
    # the file will have been copied to the ngz final path
    # so delete the copy in the tmp directory
    FileUtils.rm_rf zip_path
  end

  def ngz_work_path
    return @ngz_work_path if @ngz_work_path
    basename = title.parameterize
    local_asset_path = "files"
    @ngz_work_path = File.join(Dir::tmpdir, "#{basename}-#{Time.now.to_i}")
  end

  def to_ngz
    start_log_timer "#{self} to_ngz"
    ordered_guide_taxa = guide_taxa.order(:position).includes({:guide_photos => [:photo]}, :guide_ranges, :guide_sections, :tags)
    image_sizes = %w(thumb small medium)
    local_asset_path = "files"
    work_path = ngz_work_path
    FileUtils.mkdir_p work_path, :mode => 0755
    # build xml and write to file in tmpdir
    xml_fname = "#{id}.xml"
    xml_path = File.join(work_path, xml_fname)
    open xml_path, 'w' do |f|
      f.write FakeView.render(:template => "guides/show", :formats => [:xml], :locals => {
        :local_asset_path => local_asset_path, 
        :guide => self,
        :guide_taxa => ordered_guide_taxa,
        :image_sizes => image_sizes
      })
    end

    # mkdir for assests
    full_asset_path = File.join(work_path, local_asset_path)
    FileUtils.mkdir_p full_asset_path, :mode => 0755
    # loop over all photos and ranges, downloading assets to the asset dir
    ordered_guide_taxa.each do |gt|
      threads = []
      (gt.guide_photos + gt.guide_ranges).each do |gp|
        image_sizes.each do |s|
          next unless url = gp.send("#{s}_url") rescue nil
          fname = FakeView.guide_asset_filename(gp, :size => s)
          path = File.join(full_asset_path, fname)
          threads << Thread.new(path, url) do |thread_path,thread_url|
            Rails.logger.info "[INFO #{Time.now}] Fetching #{thread_url} to #{thread_path}"
            begin
              open(thread_path, 'wb') do |f|
                open(URI.parse(URI.encode(thread_url))) do |fr|
                  f.write(fr.read)
                end
              end
            rescue OpenURI::HTTPError => e
              Rails.logger.error "[ERROR #{Time.now}] Failed to download #{thread_url}: #{e}"
              next
            end
          end
        end
      end
      threads.each(&:join) # block until all threads finished
    end

    # zip up the results & return the path
    zip_path = "#{work_path}.ngz"
    system "cd #{work_path} && zip -qr #{zip_path} #{xml_fname} #{local_asset_path}"
    FileUtils.rm_rf work_path # clean up all those big files
    end_log_timer
    zip_path
  end

  def user_login
    user.try(:login) || I18n.t(:deleted_user)
  end

  def icon_url
    icon.file? ? icon.url(:span2) : nil
  end

  def as_json(options = {})
    options[:include] = if options[:include].is_a?(Hash)
      options[:include].map{|k,v| {k => v}}
    else
      [options[:include]].flatten.compact
    end
    options[:methods] ||= []
    options[:methods] += [:user_login, :icon_url]
    h = super(options)
    h.each do |k,v|
      h[k] = v.gsub(/<script.*script>/i, "") if v.is_a?(String)
    end
    h
  end

  def unique_tags
    ActsAsTaggableOn::Tag.joins(:taggings).where(taggings: { taggable_type: "GuideTaxon" })
  end

  def published?
    !published_at.blank? && errors[:published_at].blank?
  end

  def must_have_some_guide_taxa_to_publish
    errors.add(:published_at, :published_at_needs_3_taxa) if published? && guide_taxa.count < 3
  end
end
