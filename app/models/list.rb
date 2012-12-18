#
# A List is a list of taxa.  Naturalists often keep lists of taxa, whether
# they be lists of things they've seen, lists of things they'd like to see, or
# just lists of taxa that interest them for some reason.
#
class List < ActiveRecord::Base
  belongs_to :user
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
    ListedTaxon.create(options.merge(:list => self, :taxon => taxon))
  end
  
  #
  # Update all the taxa in this list, or just a select few.  If taxa have been
  # more recently observed, their last_observation will be updated.  If taxa
  # were selected that were not in the list, they will be added if they've
  # been observed.
  #
  def refresh(options = {})
    find_options = {}
    if taxa = options[:taxa]
      find_options[:conditions] = ["list_id = ? AND taxon_id IN (?)", self.id, taxa]
    else
      find_options[:conditions] = ["list_id = ?", self.id]
    end
    
    ListedTaxon.do_in_batches(find_options) do |listed_taxon|
      listed_taxon.skip_update_cache_columns = options[:skip_update_cache_columns]
      # re-apply list rules to the listed taxa
      listed_taxon.save
      unless listed_taxon.valid?
        Rails.logger.debug "[DEBUG] #{listed_taxon} wasn't valid, so it's being " +
          "destroyed: #{listed_taxon.errors.full_messages.join(', ')}"
        listed_taxon.destroy
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
  
  def cache_columns_query_for(lt)
    lt = ListedTaxon.find_by_id(lt) unless lt.is_a?(ListedTaxon)
    return nil unless lt
    ancestry_clause = [lt.taxon_ancestor_ids, lt.taxon_id].flatten.map{|i| i.blank? ? nil : i}.compact.join('/')
    sql_key = "EXTRACT(month FROM observed_on) || substr(quality_grade,1,1)"
    <<-SQL
      SELECT
        array_agg(o.id) AS ids,
        count(*),
        (#{sql_key}) AS key
      FROM
        observations o
          LEFT OUTER JOIN taxa t ON t.id = o.taxon_id
      WHERE
        o.user_id = #{user_id} AND
        (
          o.taxon_id = #{lt.taxon_id} OR 
          t.ancestry = '#{ancestry_clause}' OR
          t.ancestry LIKE '#{ancestry_clause}/%'
        )
      GROUP BY #{sql_key}
    SQL
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
  
  def generate_csv(options = {})
    controller = options[:controller] || FakeView.new
    attrs = %w(taxon_name description occurrence_status establishment_means adding_user_login first_observation last_observation url created_at updated_at taxon_common_name)
    ranks = %w(kingdom phylum class sublcass superorder order suborder superfamily family subfamily tribe genus)
    headers = options[:taxonomic] ? ranks + attrs : attrs
    fname = options[:fname] || "#{to_param}.csv"
    fpath = options[:path] || File.join(options[:dir] || Dir::tmpdir, fname)
    
    # Always generate file to tmp path first
    tmp_path = File.join(Dir::tmpdir, fname)
    FileUtils.mkdir_p File.dirname(tmp_path), :mode => 0755
    
    find_options = {
      :order => "taxon_ancestor_ids || '/' || listed_taxa.taxon_id",
      :include => [:taxon, :user]
    }
    if is_a?(CheckList) && is_default?
      find_options[:select] = "DISTINCT (taxon_ancestor_ids || '/' || listed_taxa.taxon_id), listed_taxa.*"
      find_options[:conditions] = ["place_id = ?", place_id]
    else
      find_options[:conditions] = ["list_id = ?", id]
    end
    
    ancestor_cache = {}
    CSV.open(tmp_path, 'w') do |csv|
      csv << headers
      ListedTaxon.do_in_batches(find_options) do |lt|
        row = []
        if options[:taxonomic]
          ancestor_ids = lt.taxon.ancestor_ids.map{|tid| tid.to_i}
          uncached_ancestor_ids = ancestor_ids - ancestor_cache.keys
          if uncached_ancestor_ids.size > 0
            Taxon.all(:select => "id, rank, name", :conditions => ["id IN (?)", uncached_ancestor_ids]).compact.each do |t|
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
    FileUtils.mkdir_p File.dirname(fpath), :mode => 0755
    if tmp_path != fpath
      FileUtils.mv tmp_path, fpath
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
    {:controller => "lists", :action => "icon_preview", :list_id => list_id}
  end
  
  def self.refresh_for_user(user, options = {})
    options = {:add_new_taxa => true}.merge(options)
    
    # Find lists that needs refreshing (either LifeLists or normal lists with 
    # these taxa).  Another approach might be to look at all listed_taxa of
    # these taxa and all rules applying to ancestors of these taxa, but the
    # ancestry check will be performed by life lists during the validations
    # anyway, so it seems like duplication.
    target_lists = if options[:taxa]
      user.lists.all(
        :include => :listed_taxa,
        :conditions => [
          "listed_taxa.taxon_id in (?) OR type = ?", 
          options[:taxa], LifeList.to_s
        ]
      )
    else
      user.lists.all
    end
    
    target_lists.each do |list|
      Rails.logger.debug "[DEBUG] refreshing #{list}..."
      list.refresh(options)
    end
    true
  end
  
  def self.refresh(list, options = {})
    list = List.find_by_id(list) unless list.is_a?(List)
    if list.blank?
      Rails.logger.error "[ERROR #{Time.now}] Failed to refresh list #{list} because it doesn't exist."
    else
      list.refresh(options)
    end
  end
  
  def self.refresh_with_observation(observation, options = {})
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
    listed_taxa = ListedTaxon.all(:include => [:list],
      :conditions => ["taxon_id IN (?) AND list_id IN (?)", taxon_ids, target_list_ids])
    if respond_to?(:create_new_listed_taxa_for_refresh)
      create_new_listed_taxa_for_refresh(taxon, listed_taxa, target_list_ids)
    end
    listed_taxa.each do |lt|
      refresh_listed_taxon(lt)
    end
  end
  
  def self.refresh_listed_taxon(lt)
    lt.save
  end
  
  def self.refresh_with_observation_lists(observation, options = {})
    user = observation.try(:user) || User.find_by_id(options[:user_id])
    return [] unless user
    if options[:skip_subclasses]
      user.lists.all(:select => "id, type", :conditions => "type IS NULL").map{|l| l.id}
    else
      user.list_ids
    end
  end
end
