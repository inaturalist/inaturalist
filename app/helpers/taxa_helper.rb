module TaxaHelper
  include ActionView::Helpers::AssetTagHelper
  
  #
  # Take two taxa that seem identical and chose one, based mostly on the 
  # number of child taxa.  Returns the one taxon to rule them all.
  #
  # WARNING: this method is ONLY intended to deal with the taxa and taxon
  # names.  You need to deal with things like observations of these taxa, list
  # rules of these taxa on your own.  Make sure you compile all these before
  # running this method and them add them to the meged taxon that gets
  # returned.
  #
  def merge_taxa(taxa)    
    if taxa.map {|t| t.name}.uniq.size > 1
      raise "These taxa don't all have the same name!  Unique names: " +
            taxa.map {|t| t.name}.uniq.join(',')
    end
    if taxa.map {|t| t.rank}.uniq.size > 1
      raise "These taxa aren't all of the same rank!  Unique ranks: " + 
            taxa.map {|t| t.rank}.uniq.join(',')
    end
    if taxa.map {|t| t.ancestors}.uniq.size > 1
      raise "These taxa aren't all siblings (i.e. they don't all have the " +
            "same ancestors)"
    end
    sorted_taxa = taxa.sort { |a,b| a.children.size > b.children.size }
    merged_taxon = sorted_taxa.shift
    
    # merge the children
    orphans = sorted_taxa.map { |taxon| taxon.children }.flatten
    orphans.each do |child|
      merged_taxon.children << child
    end
    
    # merge the taxon_names
    orphaned_names = sorted_taxa.map { |taxon| taxon.taxon_names }.flatten
    orphaned_names.each do |taxon_name|
      merged_taxon.taxon_names << taxon_name
    end
    
    # Save the survivor, destroy the pretenders
    merged_taxon.save
    sorted_taxa.each { |taxon| taxon.destroy }
    
    merged_taxon
  end
  
  #
  # Image tag for a taxon.  Returns the first assoc. photo if there is one,
  # otherwise the iconic taxon icon.
  #
  def taxon_image(taxon, params = {})
    return iconic_taxon_image(taxon, params) if taxon.flickr_photos.empty?
    image_params = {:alt => default_taxon_name(taxon)}
    unless taxon.flickr_photos.empty?
      image_params[:alt] += " - Photo #{taxon.flickr_photos.first.attribution}"
    end
    image_params[:title] = image_params[:alt]
    
    [:id, :class, :alt, :title].each do |attr_name|
      image_params[attr_name] = params.delete(attr_name) if params[attr_name]
    end
    image_tag(taxon_image_url(taxon, params), image_params)
  end
  
  def taxon_image_url(taxon, params = {})
    return iconic_taxon_image_url(taxon, params) if taxon.flickr_photos.empty?
    size = params[:size] ? "#{params[:size]}_url" : 'square_url'
    taxon.flickr_photos.first.send(size)
  end
  
  #
  # Image tag for an iconic taxon icon.  Takes the same params as
  # iconic_taxon_image_url and image_tag
  #
  def iconic_taxon_image(taxon, params = {})
    path = iconic_taxon_image_url(taxon, params)
    params.delete(:color)
    params.delete(:size)
    params[:class] = params[:class] ? "#{params[:class]} iconic" : 'iconic'
    image_tag(path, params)
  end
  
  #
  # URL of this taxon's icon, using the following convention
  #
  #   /images/iconic_taxa/[taxon_name]-[color]-[size]px.png
  #
  # where :color and :size are values you can pass in as params.  Right now,
  # it returns a path for the taxon's iconic_taxon, or itself if it IS an
  # iconic taxon.  If/when we support chosen images for taxa (instead of just
  # photos tagged with the scientific name), maybe we should use one of them
  # as the icon for non-iconic taxa...
  #
  # Example:
  #  >> iconic_taxon_image_url(Taxon.find_by_name('Aves'))
  #  => "/images/iconic_taxa/aves.png"
  #  >> iconic_taxon_image_url(Taxon.find_by_name('Aves'), :color => 'ffaa00', :size => 20)
  #  => "/images/iconic_taxa/aves-ffaa00-20px.png"
  # 
  def iconic_taxon_image_url(taxon, params = {})
    params[:size] = nil unless params[:size].is_a? Fixnum
    params[:size] ||= 32
    iconic_taxon = if taxon
      taxon.is_iconic? ? taxon : taxon.iconic_taxon
    else
      nil
    end
    path = 'iconic_taxa/'
    if iconic_taxon
      path += iconic_taxon.name.downcase
    else
      path += 'unknown'
    end
    path += '-' + params[:color] if params[:color]
    path += "-%spx" % params[:size] if params[:size]
    path += '.png'
    image_path(path)
  end
  
  #
  # Return a default name string for this taxon, English common if available.
  #
  def default_taxon_name(taxon, options = {})
    return '' unless taxon
    if options[:use_iconic_taxon_display_name] && taxon.is_iconic? && 
        Taxon::ICONIC_TAXON_DISPLAY_NAMES[taxon.name]
      return Taxon::ICONIC_TAXON_DISPLAY_NAMES[taxon.name]
    end
    taxon.default_name.name
  end
  
  def jit_taxon_node(taxon, options = {})
    options[:depth] ||= 1
    node = {
      :id => taxon.id,
      :name => taxon.name,
      :data => {
        :wikipedia_summary => taxon.wikipedia_summary
      }
    }
    node[:children] = []
    unless options[:depth] == 0
      node[:children] = taxon.children.compact.map do |c|
        jit_taxon_node(c, options[:depth] - 1)
      end
    end
    node[:data][:html] = if self.is_a?(ActionController::Base)
      render_to_string(:partial => 'taxa/taxon.html.erb', :object => taxon)
    else
      render(:partial => 'taxa/taxon.html.erb', :object => taxon)
    end

    node
  end
  
  def jit_taxon_tree_with_taxon(taxon)
    ancestors = taxon.self_and_ancestors
    root = jit_taxon_node(ancestors.first)
    previous_node = root
    ancestors[1..-1].each do |ancestor|
      logger.debug "[DEBUG] Trying to place #{ancestor} among the children of #{previous_node[:name]}..."
      ancestor_node = jit_taxon_node(ancestor)
      # Replace the child with a child with its own children
      previous_node[:children].each_with_index do |child, i|
        next unless child[:id] == ancestor.id
        previous_node[:children][i] = ancestor_node
        break
      end
      previous_node = ancestor_node
    end
    root
  end
  
  # Abbreviate a binomal / trinomail name string.  Homo sapiens => H. sapiens
  def abbreviate_binomial(name)
    (name.split[0..-2].map{|s| s.first.upcase} + [name.split.last]).join('. ')
  end
end
