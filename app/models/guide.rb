class Guide < ActiveRecord::Base
  attr_accessible :description, :latitude, :longitude, :place_id, :published_at, :title, :user_id
  belongs_to :user, :inverse_of => :guides
  has_many :guide_taxa, :inverse_of => :guide, :dependent => :destroy

  def import_taxa(options = {})
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
end
