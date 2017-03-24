#
# A List is a list of taxa.  Naturalists often keep lists of taxa, whether
# they be lists of things they've seen, lists of things they'd like to see, or
# just lists of taxa that interest them for some reason.
#
class List < ActiveRecord::Base
  acts_as_spammable fields: [:title, :description],
                    comment_type: "item-description",
                    automated: false
  belongs_to :user
  has_one :check_list_place, class_name: "Place", foreign_key: :check_list_id
  has_many :rules, :class_name => 'ListRule', :dependent => :destroy
  has_many :listed_taxa, :dependent => :destroy
  has_many :taxa, :through => :listed_taxa
  
  after_create :refresh
  
  validates_presence_of :title
  
  RANK_RULE_OPERATORS = %w(species? species_or_lower?)
  
  def rank_rule
    if (r = rules.detect{|r| r.operator == 'species?'}) then r.operator
    elsif (r = rules.detect{|r| r.operator == 'species_or_lower?'}) then r.operator
    else 'any'
    end
  end
  
  def rank_rule=(new_rank_rule)
    return if rank_rule == new_rank_rule
    return if rank_rule.blank?
    rules.each do |rule|
      rule.destroy if RANK_RULE_OPERATORS.include?(rule.operator)
    end
    
    case new_rank_rule
    when "species?"          then self.rules.build(:operator => "species?")
    when "species_or_lower?" then self.rules.build(:operator => "species_or_lower?")
    end
  end
  
  def to_s
    "<#{self.class} #{id}: #{title}>"
  end
  
  def to_param
    return nil if new_record?
    CGI.escape("#{id}-#{title.gsub(/[\'\"]/, '').gsub(/\W/, '-')}")
  end
  
  #
  # Adds a taxon to this list and returns the listed_taxon (valid or not). 
  # Note that subclasses like LifeList may override this.
  #
  def add_taxon(taxon, options = {})
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    ListedTaxon.create(options.merge(:list => self, :taxon_id => taxon.id))
  end
  
  #
  # Update all the taxa in this list, or just a select few.  If taxa have been
  # more recently observed, their last_observation will be updated.  If taxa
  # were selected that were not in the list, they will be added if they've
  # been observed.
  #
  def refresh(options = {})
    finder = ListedTaxon.all
    if taxa = options[:taxa]
      finder = finder.where(list_id: self.id, taxon_id: taxa)
    else
      finder = finder.where(list_id: self.id)
    end
    
    finder.find_in_batches do |batch|
      batch.each do |listed_taxon|
        listed_taxon.skip_update_cache_columns = options[:skip_update_cache_columns]
        # re-apply list rules to the listed taxa
        listed_taxon.save
        unless listed_taxon.valid?
          Rails.logger.debug "[DEBUG] #{listed_taxon} wasn't valid, so it's being " +
            "destroyed: #{listed_taxon.errors.full_messages.join(', ')}"
          listed_taxon.destroy
        end
      end
    end
    true
  end
  
  # Determine whether this list can be edited or added to by a user. Default
  # permission is for the owner only. Override for subclasses.
  def editable_by?(user)
    user && self.user_id == user.id
  end
  
  def listed_taxa_editable_by?(user)
    editable_by?(user)
  end
  
  def owner_name
    self.user ? self.user.login : 'Unknown'
  end
  
  # Returns an associate that has observations
  def owner
    user
  end
    
  def refresh_key
    "refresh_list_#{id}"
  end
  
  #For lists, returns first_observation (array of [date, observation_id])
  #where date represents the first date observed (e.g. not first date added to iNat)
  def cache_columns_options(lt)
    lt = ListedTaxon.find_by_id(lt) unless lt.is_a?(ListedTaxon)
    return nil unless lt && lt.taxon_id
    filters = [ { term: { "taxon.ancestor_ids": lt.taxon_id } } ]
    filters << { term: { "user.id": user_id } } if user_id
    { filters: filters }
  end
  
  def attribution
    if source
      source.in_text
    elsif user
      user.login
    end
  end
  
  def build_taxon_rule(taxon)
    return if rules.detect{|r| r.operand_id == taxon.id && r.operand_type == 'Taxon' && r.operator == 'in_taxon?'}
    rules.build(:operand => taxon, :operator => 'in_taxon?')
  end
  
  def refresh_cache_key
    "refresh_list_#{id}"
  end

  def reload_from_observations_cache_key
    "rfo_list_#{id}"
  end
  
  def generate_csv(options = {})
    CONFIG.site ||= Site.find_by_id(CONFIG.site_id) if CONFIG.site_id
    controller = options[:controller] || FakeView.new
    attrs = %w(taxon_name description occurrence_status establishment_means adding_user_login first_observation 
       last_observation url created_at updated_at taxon_common_name confirmed_observations_count unconfirmed_observations_count)
    ranks = %w(kingdom phylum class sublcass superorder order suborder superfamily family subfamily tribe genus)
    headers = options[:taxonomic] ? ranks + attrs : attrs
    fname = options[:fname] || "#{to_param}.csv"
    fpath = options[:path] || File.join(options[:dir] || Dir::tmpdir, fname)
    
    # Always generate file to tmp path first
    tmp_path = File.join(Dir::tmpdir, fname)
    FileUtils.mkdir_p File.dirname(tmp_path), :mode => 0755
    
    is_default_checklist = (is_a?(CheckList) && is_default?)
    scope = if is_default_checklist
      ListedTaxon.joins(:taxon).where(place_id: place_id)
    else
      ListedTaxon.where(list_id: id)
    end
    scope = scope.includes({ taxon: { taxon_names: :place_taxon_names } },
      :user, :first_observation, :last_observation)
    
    ancestor_cache = {}
    taxa_recorded = {}
    CSV.open(tmp_path, 'w') do |csv|
      csv << headers
      scope.find_each do |lt|
        next if lt.taxon.blank?
        next if is_default_checklist && taxa_recorded[lt.taxon.id]
        taxa_recorded[lt.taxon.id] = true if is_default_checklist
        row = []
        if options[:taxonomic]
          ancestor_ids = lt.taxon.ancestor_ids.map{|tid| tid.to_i}
          uncached_ancestor_ids = ancestor_ids - ancestor_cache.keys
          if uncached_ancestor_ids.size > 0
            Taxon.where(id: uncached_ancestor_ids).select(:id, :name, :rank).each do |t|
              ancestor_cache[t.id] = t
            end
          end
          ancestors = ancestor_ids.map{|tid| t = ancestor_cache[tid]; t.try(:name) == 'Life' ? nil : t}.compact
          ancestors << lt.taxon
          row += ranks.map do |rank|
            ancestors.detect{|t| t.rank == rank}.try(:name)
          end
        end
        attrs.each do |h|
          row << case h
          when 'adding_user_login'
            lt.user_login
          when 'url'
            controller.instance_eval { listed_taxon_url(lt) }
          when 'first_observation', 'last_observation' 
            controller.instance_eval { observation_url(lt.send(h)) } if lt.send(h)
          else
            lt.send(h)
          end
        end
        csv << row
      end
      csv << []
      csv << ["List created at", created_at]
      csv << ["List updated at", updated_at]
      csv << ["List updated by", user.login] if user
      csv << ["CSV generated at", Time.now.utc]
    end
    
    # When the full file is ready, then move it over to the real path
    begin
      FileUtils.mkdir_p File.dirname(fpath), :mode => 0755
      if tmp_path != fpath
        FileUtils.mv tmp_path, fpath
      end
    rescue Errno::EINVAL => e
      # chown fails for some reason, maybe NFS related
      if e.message =~ /Invalid argument/
        return nil
      else
        raise e
      end
    end
    fpath
  end
  
  def generate_csv_cache_key(options = {})
    if options[:view] = "taxonomic"
      "generate_csv_taxonomic_#{id}"
    else
      "generate_csv_#{id}"
    end
  end
  
  def self.icon_preview_cache_key(list)
    list_id = list.is_a?(List) ? list.id : list
    FakeView.url_for(:controller => "lists", :action => "icon_preview", :list_id => list_id, :locale => I18n.locale)
  end
  
  def self.refresh_for_user(user, options = {})
    options = {:add_new_taxa => true}.merge(options)
    
    # Find lists that needs refreshing (either LifeLists or normal lists with 
    # these taxa).  Another approach might be to look at all listed_taxa of
    # these taxa and all rules applying to ancestors of these taxa, but the
    # ancestry check will be performed by life lists during the validations
    # anyway, so it seems like duplication.
    target_lists = if options[:taxa]
      user.lists.joins(:listed_taxa).
        where(["listed_taxa.taxon_id in (?) OR type = ?", options[:taxa], LifeList.to_s])
    else
      user.lists.all
    end
    
    target_lists.each do |list|
      Rails.logger.debug "[DEBUG] refreshing #{list}..."
      list.refresh(options)
    end
    true
  end
  
  def self.refresh(options = {})
    start = Time.now
    log_key = "#{name}.refresh #{start}"
    Rails.logger.info "[INFO #{Time.now}] Starting #{log_key}, options: #{options.inspect}"
    lists = options.delete(:lists)
    lists ||= [options] if options.is_a?(self)
    lists ||= [find_by_id(options)] unless options.is_a?(Hash)
    if options[:taxa]
      lists ||= self.joins(:listed_taxa).
        where("lists.type = ? AND listed_taxa.taxon_id IN (?)", self.name, options[:taxa])
    end

    if lists.blank?
      Rails.logger.error "[ERROR #{Time.now}] Failed to refresh lists for #{options.inspect} " + 
        "because there are no matching lists."
    else
      lists.each do |list|
        Rails.logger.info "[INFO #{Time.now}] #{log_key}, refreshing #{list}"
        list.delay(priority: INTEGRITY_PRIORITY, queue: list.is_a?(CheckList) ? "slow" : "default",
          unique_hash: { "#{ list.class.name }::refresh": { list_id: list.id, options: options } }
        ).refresh(options)
      end
    end
    Rails.logger.info "[INFO #{Time.now}] #{log_key}, finished in #{Time.now - start}s"
  end
  
  def self.refresh_with_observation(observation, options = {})
    Rails.logger.info "[INFO #{Time.now}] Starting List.refresh_with_observation for #{observation}, #{options.inspect}"
    observation = Observation.find_by_id(observation) unless observation.is_a?(Observation)
    unless taxon = Taxon.find_by_id(observation.try(:taxon_id) || options[:taxon_id])
      Rails.logger.error "[ERROR #{Time.now}] List.refresh_with_observation " + 
        "failed with blank taxon, observation: #{observation}, options: #{options.inspect}"
      return
    end
    taxon_ids = [taxon.ancestor_ids, taxon.id].flatten
    if taxon_was = Taxon.find_by_id(options[:taxon_id_was])
      taxon_ids = [taxon_ids, taxon_was.ancestor_ids, taxon_was.id].flatten.uniq
    end
    target_list_ids = refresh_with_observation_lists(observation, options)
    # get listed taxa for this taxon and its ancestors that are on the observer's life lists
    listed_taxa = ListedTaxon.
      where("listed_taxa.taxon_id IN (?) AND listed_taxa.list_id IN (?)", taxon_ids, target_list_ids)
    if respond_to?(:create_new_listed_taxa_for_refresh)
      create_new_listed_taxa_for_refresh(taxon, listed_taxa, target_list_ids)
    end
    listed_taxa.each do |lt|
      Rails.logger.info "[INFO #{Time.now}] List.refresh_with_observation, refreshing #{lt}"
      # delay taxon indexing
      lt.skip_index_taxon = true
      refresh_listed_taxon(lt)
    end
    # index taxa in bulk
    Taxon.elastic_index!(ids: listed_taxa.map(&:taxon_id).uniq)
    Rails.logger.info "[INFO #{Time.now}] Finished List.refresh_with_observation for #{observation}"
  end
  
  def self.refresh_listed_taxon(lt)
    lt.save
  end
  
  def self.refresh_with_observation_lists(observation, options = {})
    user = observation.try(:user) || User.find_by_id(options[:user_id])
    return [] unless user
    if options[:skip_subclasses]
      user.lists.where("type IS NULL").select("id, type").map{|l| l.id}
    else
      user.list_ids
    end
  end
end
