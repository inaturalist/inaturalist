#encoding: utf-8
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
    if taxon.blank? || taxon.default_photo.blank?
      return iconic_taxon_image(taxon, params)
    end
    params[:size] ||= "square"
    image_params = params.except(:size).merge(:alt => default_taxon_name(taxon))
    unless taxon.default_photo.blank?
      image_params[:alt] += " - Photo #{taxon.default_photo.attribution}"
    end
    image_params[:title] = image_params[:alt]
    
    [:id, :class, :style, :alt, :title, :width, :height].each do |attr_name|
      image_params[attr_name] = params.delete(attr_name) if params[attr_name]
    end
    image_params[:class] = "#{image_params[:class]} #{params[:size]} photo".strip
    image_tag(taxon_image_url(taxon, params), image_params).force_encoding('utf-8')
  end
  
  def taxon_image_url(taxon, params = {})
    return iconic_taxon_image_url(taxon, params) if taxon.blank? || taxon.default_photo.blank?
    size = params[:size].blank? ? 'square' : params[:size]
    photo = taxon.default_photo
    photo.best_url(size)
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
    params[:title] ||= Taxon::ICONIC_TAXON_DISPLAY_NAMES[taxon.try(:name)]
    params[:alt] ||= Taxon::ICONIC_TAXON_DISPLAY_NAMES[taxon.try(:name)]
    image_tag(path, params).force_encoding('utf-8')
  end
  
  #
  # URL of this taxon's icon, using the following convention
  #
  #   /assets/iconic_taxa/[taxon_name]-[color]-[size]px.png
  #
  # where :color and :size are values you can pass in as params.  Right now,
  # it returns a path for the taxon's iconic_taxon, or itself if it IS an
  # iconic taxon.  If/when we support chosen images for taxa (instead of just
  # photos tagged with the scientific name), maybe we should use one of them
  # as the icon for non-iconic taxa...
  #
  # Example:
  #  >> iconic_taxon_image_url(Taxon.find_by_name('Aves'))
  #  => "/assets/iconic_taxa/aves.png"
  #  >> iconic_taxon_image_url(Taxon.find_by_name('Aves'), :color => 'ffaa00', :size => 20)
  #  => "/assets/iconic_taxa/aves-ffaa00-20px.png"
  # 
  def iconic_taxon_image_url(taxon, params = {})
    params[:size] = nil unless params[:size].is_a? Integer
    params[:size] ||= 75
    iconic_taxon = Taxon::ICONIC_TAXA_BY_ID[taxon]
    iconic_taxon ||= if taxon
      taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
      unless taxon.blank?
        taxon.is_iconic? ? taxon : Taxon::ICONIC_TAXA_BY_ID[taxon.iconic_taxon_id]
      end
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
    image_url(path)
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
    tn = TaxonName.choose_default_name(
      @taxon_names_by_taxon_id ? @taxon_names_by_taxon_id[taxon.id] : taxon.taxon_names
    )
    return "" unless tn
    return tn.name if tn.is_scientific_names?
    capitalize_name( tn.name )
  end

  def common_taxon_name( taxon, options = {} )
    return nil if taxon.blank?

    user = if options[:user]
      options[:user]
    else
      @user
    end
    site = options[:site] || @site
    TaxonName.choose_common_name(
      @taxon_names_by_taxon_id ? @taxon_names_by_taxon_id[taxon.id] : taxon.taxon_names,
      place: options[:place] || user.try( :place ) || site.try( :place ),
      locale: options[:locale] || user.try( :locale ) || site.try( :locale ),
      user: user
    )
  end

  def common_taxon_names( taxon, options = {} )
    return [] if taxon.blank?

    user = options[:user]
    unless user&.taxon_name_priorities&.any?
      if ( common_name = common_taxon_name( taxon, options ).try( :name ) )
        return [common_name]
      end
      return [] unless taxon.is_iconic? || taxon.root?

      locale = options[:locale] || user&.try( :locale ) || @site&.try( :locale )
      translated_name = I18n.t(
        taxon.name.parameterize.underscore,
        scope: :all_taxa,
        locale: locale
      )
      return [translated_name] if translated_name

      return []
    end

    user.taxon_name_priorities.sort_by( &:position ).map do | tnp |
      TaxonName.choose_common_name(
        @taxon_names_by_taxon_id ? @taxon_names_by_taxon_id[taxon.id] : taxon.taxon_names,
        place: tnp.place,
        lexicon: tnp.lexicon,
        locale: tnp.lexicon ? nil : ( user.try( :locale ) || site.try( :locale ) ),
        user: user
      ).try( :name )
    end.uniq.compact
  end

  def capitalize_piece( piece )
    # \p{Word} matches any word in Unicode, \w does not, apparently
    # https://stackoverflow.com/questions/3576232/how-to-match-unicode-words-with-ruby-1-9#3576559

    # Match contractions like d'Silva
    if bits = piece.match( /^([a-z]['’])(\p{Word}+)/ )
      "#{bits[1]}#{bits[2].capitalize}"
    # Match okina and similar leading punctuation characters that will match \p{Word}
    elsif bits = piece.match( /^([ʻ])(\p{Word}+)/)
      "#{bits[1]}#{bits[2].capitalize}"
    elsif bits = piece.match( /(.*?)(\p{Word}+)(.*)/ )
      "#{bits[1]}#{bits[2].capitalize}#{bits[3]}"
    else
      piece
    end
  end

  def capitalize_name( comname )
    uncapitalized = [
      "à",
      "a",
      "and",
      "con",
      "da",
      "dal",
      "de",
      "dei",
      "del",
      "des",
      "di",
      "du",
      "e",
      "in",
      "la",
      "o",
      "on",
      "of",
      "the"
    ]
    comname_pieces = comname.split( /\s+/ )
    comname_pieces.each_with_index.map{ |piece, i|
      if i > 0 && uncapitalized.include?( piece.downcase )
        piece.downcase
      elsif i == comname_pieces.size - 1
        piece.split( "-" ).map{ |s| uncapitalized.include?( s.downcase ) ? s.downcase : capitalize_piece( s ) }.join( "-" )
      else
        capitalize_piece( piece )
      end
    }.join( " " )
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
      node[:children] = taxon.children.to_a.compact.map do |c|
        jit_taxon_node(c, :depth => options[:depth] - 1)
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
      Rails.logger.debug "[DEBUG] Trying to place #{ancestor} among the children of #{previous_node[:name]}..."
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
  
  def remote_taxon_images(taxon, options = {})
    limit = options.delete(:limit)
    element_id = dom_id(taxon, "images")
    key = {:controller => 'taxa', :action => 'photos', :id => taxon.id, :partial => "photo"}
    if controller.fragment_exist?(key)
      return content_tag(:div, controller.read_fragment(key), :id => element_id)
    end
    html = content_tag(:div, t(:loading_images), :id => element_id, :class => "loading status")
    js = <<-JS
      $('##{element_id}').load('#{photos_of_taxon_path(taxon, :partial => "photo", :limit => limit)}', function() {
        $('.zoomable', this).zoomify();
        $('##{element_id}').removeClass('loading status');
      });
    JS
    html += content_tag(:script, js.html_safe, :type => "text/javascript")
    html
  end
  
  # Lame but simple way to jsonify a taxon
  def taxon_to_json(taxon, options = {})
    {
      :id => taxon.id,
      :name => taxon.name,
      :rank => taxon.rank,
      :rank_level => taxon.rank_level,
      :iconic_taxon => options[:iconic_taxon] || taxon.iconic_taxon,
      :taxon_names => taxon.taxon_names,
      :photos => taxon.photos,
      :common_name => taxon.common_name,
      :image_url => taxon.image_url,
      :default_name => taxon.default_name
    }.to_json
  end
  
  def iconic_taxon_color(taxon)
    taxon = Taxon::ICONIC_TAXA_BY_ID[taxon.to_i] unless taxon.is_a?(Taxon)
    taxon = Taxon::ICONIC_TAXA_BY_ID[taxon.iconic_taxon_id] if taxon && !taxon.is_iconic?
    case taxon.try(:name)
    when "Animalia", "Actinopterygii", "Amphibia", "Reptilia", "Aves", "Mammalia" then "1E90FF"
    when "Insecta", "Arachnida", "Mollusca" then "FF4500"
    when "Plantae" then "73AC13"
    when "Fungi" then "FF1493"
    when "Protozoa" then "691776"
    else nil
    end
  end
  
  def taxon_range_kml_url(options = {})
    taxon_range = options[:taxon_range] || @taxon_range
    return nil if taxon_range.blank?
    if taxon_range.range.blank?
      taxon_range.kml_url
    else
      "#{taxon_range.kml_url}?#{taxon_range.updated_at.to_i}".html_safe
    end
  end

end
