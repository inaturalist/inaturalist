#
# A List is a list of taxa.  Naturalists often keep lists of taxa, whether
# they be lists of things they've seen, lists of things they'd like to see, or
# just lists of taxa that interest them for some reason.
#
class List < ApplicationRecord
  acts_as_spammable fields: [:title, :description],
                    comment_type: "item-description",
                    automated: false
  belongs_to :user
  has_one :check_list_place, class_name: "Place", foreign_key: :check_list_id
  belongs_to :place
  has_many :rules, :class_name => 'ListRule', :dependent => :destroy
  has_many :listed_taxa, :dependent => :destroy
  has_many :taxa, :through => :listed_taxa
  
  validates_presence_of :title
  
  RANK_RULE_SPECIES = "species?"
  RANK_RULE_SPECIES_OR_LOWER = "species_or_lower?"
  RANK_RULE_OPERATORS = [RANK_RULE_SPECIES, RANK_RULE_SPECIES_OR_LOWER]
  MAX_RELOAD_TRIES = 60
  
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
  # Note that subclasses like CheckList may override this.
  #
  def add_taxon(taxon, options = {})
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    ListedTaxon.create( options.merge( list: self, taxon: taxon ) )
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
  
  def generate_csv(options = {})
    controller = options[:controller] || FakeView.new
    attrs = %w(taxon_name description occurrence_status establishment_means adding_user_login first_observation 
       last_observation url created_at updated_at taxon_common_name)
    ranks = Taxon::RANK_LEVELS.select{|r,l| (Taxon::COMPLEX_LEVEL..Taxon::KINGDOM_LEVEL).include?(l) }.keys - [Taxon::GENUSHYBRID]
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
    key = (options[:view] == "taxonomic") ? "generate_csv_taxonomic_#{id}" : "generate_csv_#{id}"
    key << "_#{options[:user_id]}" if options[:user_id]
    key
  end

  def self.icon_preview_cache_key( list )
    list_id = list.is_a?( List ) ? list.id : list
    UrlHelper.icon_preview_list_url list_id, locale: I18n.locale
  end
end
