class Observation < ActiveRecord::Base
  acts_as_taggable
  acts_as_flaggable
  
  # Set to true if you want to skip the expensive updating of all the user's
  # lists after saving.  Useful if you're saving many observations at once and
  # you want to update lists in a batch
  attr_accessor :skip_refresh_lists

  belongs_to :user, :counter_cache => true
  belongs_to :taxon, :counter_cache => true
  belongs_to :iconic_taxon, :class_name => 'Taxon', 
                            :foreign_key => 'iconic_taxon_id'
  
  # has_one  :activity_update, :as => :activity_object
  
  has_many :photos
  has_many :listed_taxa, :foreign_key => 'last_observation_id'
  has_many :goal_contributions,
           :as => :contribution,
           :dependent => :destroy
  has_many :comments, :as => :parent, :dependent => :destroy
  has_many :identifications, :dependent => :delete_all
  has_many :markings, :dependent => :destroy
  has_many :marking_types,
           :through => :markings
               
  has_and_belongs_to_many :flickr_photos, :uniq => true
  
  define_index do
    indexes taxon.taxon_names.name, :as => :names
    indexes tags.name, :as => :tags
    indexes :species_guess, :sortable => true
    indexes :description
    indexes :place_guess, :as => :place, :sortable => true
    indexes user.login, :as => :user, :sortable => true
    indexes :observed_on_string
    has :user_id
    has :taxon_id
    
    # Sadly, the following doesn't work, because self_and_ancestors is not an
    # association.  I'm not entirely sure if there's a way to work the ancestry
    # query in as col in a SQL query on observations.  If at some point we
    # need to have the ancestor ids in the Sphinx index, though, we can always
    # add a col to the taxa table holding the ancestor IDs.  Kind of a
    # redundant, and it would slow down moves, but it might be worth it for
    # the snappy searches. --KMU 2009-04-4
    # has taxon.self_and_ancestors(:id), :as => :taxon_self_and_ancestors_ids
    
    has flickr_photos(:id), :as => :has_photos, :type => :boolean
    has :created_at, :sortable => true
    has :observed_on, :sortable => true
    has :iconic_taxon_id
    has :id_please, :as => :has_id_please
    has "latitude IS NOT NULL AND longitude IS NOT NULL", 
      :as => :has_geo, :type => :boolean
    has 'RADIANS(latitude)', :as => :latitude,  :type => :float
    has 'RADIANS(longitude)', :as => :longitude,  :type => :float
    has "num_identification_agreements > num_identification_disagreements",
      :as => :identifications_most_agree, :type => :boolean
    has "num_identification_agreements > 0", 
      :as => :identifications_some_agree, :type => :boolean
    has "num_identification_agreements < num_identification_disagreements",
      :as => :identifications_most_disagree, :type => :boolean
    set_property :delta => true
  end

  ##
  # Validations
  #
  validates_presence_of :user_id
  
  validate :must_be_in_the_past,
           :must_not_be_a_range
  
  validates_numericality_of :latitude, {
    :on => :create, 
    :allow_nil => true, 
    :less_than_or_equal_to => 90, 
    :greater_than_or_equal_to => -90
  }
  validates_numericality_of :longitude, {
    :on => :create, 
    :allow_nil => true, 
    :less_than_or_equal_to => 180, 
    :greater_than_or_equal_to => -180
  }
  
  before_validation :munge_observed_on_with_chronic,
                    :set_time_zone,
                    :set_time_in_time_zone,
                    :cast_lat_lon
  
  before_save :strip_species_guess,
              # :scrub_instructions_before_save,
              :set_iconic_taxon,
              :keep_old_taxon_id
                 
  after_save :refresh_lists,
             :update_identifications_after_save
             # :update_goal_contributions,
             
  
  before_destroy :keep_old_taxon_id
  after_destroy :refresh_lists_after_destroy
  
  # Activity updates
  # after_create :create_activity_update
  # after_save :update_activity_update
  # before_destroy :delete_activity_update
  
  ##
  # Named scopes
  # 
  
  # Area scopes
  named_scope :in_bounding_box, lambda { |swlat, swlng, nelat, nelng|
    if swlng.to_f > 0 && nelng.to_f < 0
      {:conditions => ['latitude > ? AND latitude < ? AND (longitude > ? OR longitude < ?)',
                        swlat, nelat, swlng, nelng]}
    else
      {:conditions => ['latitude > ? AND latitude < ? AND longitude > ? AND longitude < ?',
                        swlat, nelat, swlng, nelng]}
    end
  } do
    def distinct_taxon
      find(:all, :group => "taxon_id", :conditions => "taxon_id IS NOT NULL", :include => :taxon)
    end
  end
  
  # inneficient radius in kilometers, needs testing
  named_scope :near_point, Proc.new { |lat, lng, radius|
    radius ||= 10.0
    {:conditions => ['6378.7 * acos(sin(?/57.2958) * sin(latitude/57.2958) + cos(?/57.2958) * cos(latitude/57.2958) *  cos(longitude/57.2958 -?/57.2958)) < ?',
                     lat.to_f, lat.to_f, lng.to_f, radius]}
  }
  
  # Has_property scopes
  named_scope :has_taxon, lambda { |taxon_id|
    if taxon_id.nil?
    then return {:conditions => "taxon_id IS NOT NULL"}
    else {:conditions => ["taxon_id IN (?)", taxon_id]}
    end
  }
  named_scope :has_iconic_taxa, lambda { |iconic_taxon_ids|
    iconic_taxon_ids = [iconic_taxon_ids].flatten # make array if single
    if iconic_taxon_ids.include?(nil)
      {:conditions => [
        "observations.iconic_taxon_id IS NULL OR observations.iconic_taxon_id IN (?)", 
        iconic_taxon_ids]}
    elsif !iconic_taxon_ids.empty?
      {:conditions => [
        "observations.iconic_taxon_id IN (?)", iconic_taxon_ids]}
    end
  }
  
  named_scope :has_geo, :conditions => ["latitude IS NOT NULL AND longitude IS NOT NULL"]
  named_scope :has_id_please, :conditions => ["id_please IS TRUE"]
  named_scope :has_photos, 
              :include => :flickr_photos,
              :group => 'observations.id',
              :conditions => ['flickr_photos.id IS NOT NULL']
  
  
  # Find observations by a taxon object
  named_scope :of, lambda { |taxon|
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a? Taxon
    return {:conditions => "1 = 2"} unless taxon
    {:include => :taxon,
     :conditions => ['taxa.lft >= ? AND taxa.rgt <= ?', taxon.lft, taxon.rgt]}
  }
  
  # Find observations by user
  named_scope :by, lambda { |user| 
    {:conditions => ["observations.user_id = ?", user]}
  }
  
  # Order observations by date and time observed
  named_scope :latest, :order => "observed_on DESC, time_observed_at DESC"
  
  # TODO: Make this work for any SQL order statement, including multiple cols
  named_scope :order_by, lambda { |order|
    order_by, order = order.split == [order] ? [order, 'ASC'] : order.split
    options = {}
    case order_by
    when 'observed_on'
      options[:order] = "observed_on #{order}, " + 
                        "time_observed_at #{order}"
    when 'user'
      options[:include] = [:user]
      options[:order] = "users.login #{order}"
    when 'place'
      options[:order] = "place_guess #{order}"
    when 'created_at'
      options[:order] = "observations.created_at #{order}"
    else
      options[:order] = "#{order_by} #{order}"
    end
    options
  }
  
  named_scope :identifications, lambda { |agreement|
    limited_scope = {:include => :identifications}
    case agreement
    when 'most_agree'
      limited_scope[:conditions] = "num_identification_agreements > num_identification_disagreements"
    when 'some_agree'
      limited_scope[:conditions] = "num_identification_agreements > 0"
    when 'most_disagree'
      limited_scope[:conditions] = "num_identification_agreements < num_identification_disagreements"
    end
    limited_scope
  }
  
  # Time based named scopes
  named_scope :created_after, lambda { |time|
    {:conditions => ['created_at >= ?', time]}
  }
  
  named_scope :created_before, lambda { |time|
    {:conditions => ['created_at <= ?', time]}
  }
  
  named_scope :updated_after, lambda { |time|
    {:conditions => ['updated_at >= ?', time]}
  }
  
  named_scope :updated_before, lambda { |time|
    {:conditions => ['updated_at <= ?', time]}
  }
  
  named_scope :observed_after, lambda { |time|
    {:conditions => ['time_observed_at >= ?', time]}
  }
  
  named_scope :observed_before, lambda { |time|
    {:conditions => ['time_observed_at <= ?', time]}
  }
  
  #
  # Uses scopes to perform a conditional search.
  # May be worth looking into squirrel or some other rails friendly search add on
  #
  def self.query(params = {})
    scope = self.scoped({})
    
    # support bounding box queries
     if (!params[:swlat].blank? && !params[:swlng].blank? && 
         !params[:nelat].blank? && !params[:nelng].blank?)
      scope = scope.in_bounding_box(params[:swlat], params[:swlng], params[:nelat], params[:nelng])
    elsif (params[:lat] and params[:lng])
      scope = scope.near_point(params[:lat], params[:lng], params[:radius])
    end
    
    # has (boolean) selectors
    if (params[:has])
      params[:has] = params[:has].split(',') if params[:has].is_a? String
      params[:has].each do |prop|
        case prop
          when 'geo' then scope = scope.has_geo
          when 'id_please' then scope = scope.has_id_please
          when 'photos' then scope = scope.has_photos
          # hmmm... this seems less than ideal
          else scope = scope.conditions "? IS NOT NULL OR ? != ''", prop, prop
        end
      end
    end
    
    scope = scope.identifications(params[:identifications]) if (params[:identifications])
    scope = scope.has_iconic_taxa(params[:iconic_taxa]) if params[:iconic_taxa]
    scope = scope.order_by(params[:order_by]) if params[:order_by]
    scope = scope.of(params[:taxon_id]) if params[:taxon_id]
    scope = scope.by(params[:user_id]) if params[:user_id]
    
    # return the scope, we can use this for will_paginate calls like:
    # Observation.query(params).paginate()
    scope
  end
  # help_txt_for :species_guess, <<-DESC
  #   Type a name for what you saw.  It can be common or scientific, accurate 
  #   or just a placeholder. When you enter it, we'll try to look it up and find
  #   the matching species of higher level taxon.
  # DESC
  # 
  # instruction_for :place_guess, "Type the name of a place"
  # help_txt_for :place_guess, <<-DESC
  #   Enter the name of a place and we'll try to find where it is. If we find
  #   it, you can drag the map marker around to get more specific.
  # DESC
  
  def to_s
    "<Observation #{self.id}: #{to_plain_s}>"
  end
  
  def to_plain_s(options = {})
    s = self.species_guess.blank? ? 'something' : self.species_guess
    unless self.place_guess.blank? || options[:no_place_guess]
      s += " in #{self.place_guess}"
    end
    s += " on #{self.observed_on.to_s(:long)}" unless self.observed_on.blank?
    unless self.time_observed_at.blank? || options[:no_time]
      s += " at #{self.time_observed_at_in_zone.to_s(:plain_time)}"
    end
    s += " by #{self.user.login}" unless options[:no_user]
    s
  end
  
  # Used to help user debug their CSV files
  # TODO: move this to a helper
  def csv_record_to_s
    "Required Columns in order<br />"
      "Species Guess: #{self.species_guess}<br />"+
      "Observed On: #{self.observed_on}, which is interpreted as #{datetime}<br />"+
      "Description: #{self.description}<br />"+
      "Place Guess: #{self.place_guess}<br />"+
      "Optional Columns (Note: for any of these columns to be used in an observation, they must all be present)<br />"+
      "Latitude: #{self.latitude}<br />"+
      "Longitude: #{self.longitude}<br />"+
      "Location is exact: #{self.location_is_exact}"
  end

  #
  # Return a time from observed_on and time_observed_at
  #
  def datetime
    if self.observed_on
      if self.time_observed_at
        Time.mktime(self.observed_on.year, 
                    self.observed_on.month, 
                    self.observed_on.day, 
                    self.time_observed_at.hour, 
                    self.time_observed_at.min, 
                    self.time_observed_at.sec, 
                    self.time_observed_at.zone)
      else
        Time.mktime(self.observed_on.year, 
                    self.observed_on.month, 
                    self.observed_on.day)
      end
    end
  end
  
  # Return time_observed_at in the observation's time zone
  def time_observed_at_in_zone
    self.time_observed_at.in_time_zone(self.time_zone)
  end
  
  #
  # Set all the time fields based on the contents of observed_on_string
  #
  def munge_observed_on_with_chronic
    # Set the time zone appropriately
    old_time_zone = Time.zone
    Time.zone = self.user.time_zone unless self.user.nil? || self.user.time_zone.blank?
    Time.zone = self.time_zone unless self.time_zone.blank?    
    Chronic.time_class = Time.zone
    
    begin
      # Start parsing...
      return unless t = Chronic.parse(self.observed_on_string)
    
      # Re-interpret future dates as being in the past
      if t > Time.now
        t = Chronic.parse(self.observed_on_string, :context => :past)  
      end
    
      self.observed_on = t.to_date
    
      # try to determine if the user specified a time by ask Chronic to return
      # a time range. Time ranges less than a day probably specified a time.
      if tspan = Chronic.parse(self.observed_on_string, :context => :past, 
                                                      :guess => false)
        # If tspan is less than a day and the string wasn't 'today', set time
        if tspan.width < 86400 && self.observed_on_string.strip.downcase != 'today'
          self.time_observed_at = t
        else
          self.time_observed_at = nil
        end
      end
    rescue RuntimeError
      errors.add(:observed_on, 
        "was not recognized, some working examples are: yesterday, 3 years " +
        "ago, 5/27/1979, 1979-05-27 05:00. " +
        "(<a href='http://chronic.rubyforge.org/'>others</a>)")
      return
    end
    
    # don't store relative observed_on_strings, or they will change
    # every time you save an observation!
    if self.observed_on_string =~ /today|yesterday|ago|last|this|now|monday|tuesday|wednesday|thursday|friday|saturday|sunday/i
      self.observed_on_string = self.observed_on.to_s
      if self.time_observed_at
        self.observed_on_string = self.time_observed_at.strftime("%Y-%m-%d %H:%M:%S")
      end
    end
    
    # Set the time zone back the way it was
    Time.zone = old_time_zone
  end
  
  #
  # Adds, updates, or destroys the identification corresponding to the taxon
  # the user selected.
  #
  def update_identifications_after_save
    owners_ident = self.identifications.first(
      :conditions => {:user_id => self.user_id})
    
    # If there's a taxon we need to make ure the owner's ident agrees
    if self.taxon
      # If the owner doesn't have an identification for this obs, make one
      unless owners_ident
        owners_ident = Identification.create(
          :user => self.user, 
          :taxon => self.taxon,
          :observation => self)
      end
      
      # If the obs taxon and the owner's ident don't agree, make them
      if owners_ident.taxon_id != self.taxon_id
        owners_ident.taxon_id = self.taxon_id
        owners_ident.save
      end
    
    # If there's no taxon, we should destroy the owner's ident
    elsif owners_ident
      owners_ident.destroy
    end
  end
  
  #
  # Update the user's lists with changes to this observation's taxon
  #
  # If the observation is the last_observation in any of the user's lists,
  # then the last_observation should be reset to another observation.
  #
  def refresh_lists
    return if @skip_refresh_lists
    
    # Update the observation's current taxon and/or a previous one that was
    # just removed/changed
    target_taxa = [
      self.taxon, 
      Taxon.find_by_id(@old_observation_taxon_id)
    ].compact.uniq
    
    # Don't refresh all the lists if nothing changed
    return if target_taxa.empty?
    
    List.refresh_for_user(self.user, :taxa => target_taxa)
    
    # Reset the instance var so it doesn't linger around
    @old_observation_taxon_id = nil
  end
  
  # Because it has to be slightly different, in that the taxon of a destroyed
  # obs shouldn't be removed by default from life lists (maybe you've seen it
  # in the past, but you don't have any other obs), but those listed_taxa of
  # this taxon should have their last_observation reset.
  #
  def refresh_lists_after_destroy
    return if @skip_refresh_lists
    return unless self.taxon

    List.refresh_for_user(self.user, :taxa => [self.taxon], 
      :add_new_taxa => false)
  end
  
  #
  # Preserve the old taxon id if the taxon has changed so we know to update
  # that taxon in the user's lists after_save
  #
  def keep_old_taxon_id
    @old_observation_taxon_id = self.taxon_id_was if self.taxon_id_changed?
  end
  
  #
  # This is the hook used to check each observation to see if it may apply
  # to a system based goal. It does so by collecting all of the user's
  # current goals, including global goals and checking to see if the
  # observation passes each rule established by the goal. If it does, the
  # goal is recorded as a contribution in the goal_contributions table.
  #
  def update_goal_contributions
    self.user.goal_participants_for_incomplete_goals.each do |participant|
      participant.goal.validate_and_add_contribution(self, participant)
    end
    return true
  end
  
  
  #
  # Remove any instructional text that may have been submitted with the form.
  #
  def scrub_instructions_before_save
    self.attributes.each do |attr_name, value|
      if Observation.instructions[attr_name.to_sym] and value and
        Observation.instructions[attr_name.to_sym] == value
        write_attribute(attr_name.to_sym, nil)
      end
    end
  end
  
  #
  # Set the iconic taxon if it hasn't been set
  #
  def set_iconic_taxon
    return unless self.taxon_id_changed?
    if self.taxon
      self.iconic_taxon_id ||= self.taxon.iconic_taxon_id
    else
      self.iconic_taxon_id = nil
    end
  end
  
  #
  # Trim whitespace around species guess
  #
  def strip_species_guess
    self.species_guess.strip! unless self.species_guess.nil?
  end
  
  #
  # Add a marking to the observation
  #
  def mark(user_id, marking_type_id)
    self.markings << Marking.new({
      :user_id => user_id,
      :marking_type_id => marking_type_id
    })
  end
  
  #
  # Set the time_zone of this observation if not already set
  #
  def set_time_zone
    user = User.find_by_id(self.user_id)
    if user && self.time_zone.blank?
      self.time_zone = self.user.time_zone
    end
    self.time_zone ||= Time.zone
  end

  #
  # Cast lat and lon so they will (hopefully) pass the numericallity test
  #
  def cast_lat_lon
    if self.latitude
      self.latitude = self.latitude.to_f
    end
    if self.longitude
      self.longitude = self.longitude.to_f
    end
  end  

  #
  # Force time_observed_at into the time zone
  #
  def set_time_in_time_zone
    return unless self.time_observed_at && self.time_zone && (self.time_observed_at_changed? || self.time_zone_changed?)
    
    # Render the time as a string
    time_s = self.time_observed_at_before_type_cast
    unless time_s.is_a? String
      time_s = self.time_observed_at_before_type_cast.strftime("%Y-%m-%d %H:%M:%S")
    end
    
    # Get the time zone offset as a string and append it
    offset_s = Time.parse(time_s).in_time_zone(self.time_zone).formatted_offset(false)
    time_s += " #{offset_s}"
    
    self.time_observed_at = Time.parse(time_s)
  end
  
  #
  # Unmark the observation
  #
  def unmark(user_id, marking_type_id)
    marking = self.markings.find(:first,
                :conditions => ["user_id = ? AND marking_type_id = ?",
                user_id, marking_type_id])
    # no marking
    return false if marking.nil?
    marking.destroy
  end
  
  #
  # See if the observation is marked a certain type, regardless of user
  #
  def marked?(marking_type)
    marking_types.include?(marking_type)
  end
  
  #
  # See if the observation is marked something by a user
  #
  def marked_by_user?(marking_type, user)
    !markings.find(:first,
                   :conditions => ["user_id = ? AND marking_type_id = ?",
                                   user.id, marking_type.id]).nil?
  end
  
  def marking_counts_for(marking_type)
    markings.count(:conditions => ["marking_type_id = ?", marking_type.id])
  end
  
  ##### Rules ###############################################################
  #
  # This section contains all of the rules that can be used for list creation
  # or goal completion
  
  class << self # this just prevents me from having to write def self.*
    
    # Written for the Goals framework.
    # Accepts two parameters, the first is 'thing' from GoalRule,
    # the second is an array created when the GoalRule splits on pipes "|"
    def within_the_first_n_contributions?(observation, args)
      return false unless observation.instance_of? self
      return true if count <= args[0].to_i
      find(:all,
           :select => "id",
           :order => "created_at ASC",
           :limit => args[0]).include?(observation)
    end
  end

  #
  # Checks whether this observation has been flagged
  #
  def flagged?
    self.flags.select { |f| not f.resolved? }.size > 0
  end
  
  protected
  
  ##### Validations #########################################################
  #
  # Make sure the observation is not in the future.
  #
  def must_be_in_the_past
    unless self.observed_on.nil? or self.observed_on <= Date.today
      errors.add(:observed_on, "can't be in the future")
    end
  end

  #
  # Make sure the observation resolves to a single day.  Right now we don't
  # store ambiguity...
  #
  def must_not_be_a_range
    return unless self.observed_on_string
    
    is_a_range = false
    begin  
      if tspan = Chronic.parse(self.observed_on_string, 
                             :context => :past, :guess => false)
        is_a_range = true if tspan.width.seconds > 1.day.seconds
      end
    rescue RuntimeError
      errors.add(:observed_on, 
        "was not recognized, some working examples are: yesterday, 3 years " +
        "ago, 5/27/1979, 1979-05-27 05:00. " +
        "(<a href='http://chronic.rubyforge.org/'>others</a>)"
      ) 
      return
    end
    
    # Special case: dates like '2004', which ordinarily resolve to today at 
    # 8:04pm
    observed_on_int = self.observed_on_string.gsub(/[^\d]/, '').to_i
    if observed_on_int > 1900 && observed_on_int <= Date.today.year
      is_a_range = true
    end
    
    if is_a_range
      errors.add(:observed_on, "must be a single day, not a range")
    end
  end
  
  def lsid
    "lsid:inaturalist.org:observations:#{id}"
  end
  
  def create_activity_update
    require 'app/helpers/taxa_helper'
    view = ActionView::Base.new(Rails::Configuration.new.view_path, {})
    class << view
      include TaxaHelper, ApplicationHelper
    end
    snippet = view.render(:partial => 'observations/dashboard_component', :locals => {:observation => self})
    ao = ActivityUpdate.new({
      :user_id => self.user_id,
      :activity_object => self,
      :snippet => snippet
    })
    ao.save
  end
  
  # I'm not psyched about having this stuff here, but it makes generating 
  # more compact JSON a lot easier.
  include ObservationsHelper
  include ActionView::Helpers::SanitizeHelper
  include ActionView::Helpers::TextHelper
  def image_url
    observation_image_url(self)
  end
  
  def short_description
    short_observation_description(self)
  end
end
