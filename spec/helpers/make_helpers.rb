module MakeHelpers
  def make_curator
    make_user_with_role(:curator)
  end
  
  def make_admin
    make_user_with_role(User::JEDI_MASTER_ROLE)
  end
  
  def make_user_with_role(role_name)
    user = User.make!
    user.roles << Role.make!(:name => role_name.to_s)
    user
  end
  
  def make_life_list_for_taxon(taxon)
    list = LifeList.make!
    list.rules << ListRule.new(
      :operand => taxon, 
      :operator => 'in_taxon?'
    )
    list
  end
  
  def make_observation_of_threatened(options = {})
    Observation.make!(options.merge(
      :latitude => 38.333, :longitude => -122.111,
      :taxon => Taxon.make!(:threatened),
      :created_at => Time.now.to_date
    ))
  end
  
  # It's important that the lat & lon don't show up in the date when doing 
  # simple regex tests
  def make_private_observation(options = {})
    Observation.make!(options.merge(
      :latitude => 38.888, :longitude => -122.222, 
      :geoprivacy => Observation::PRIVATE, 
      :created_at => Time.now.to_date
    ))
  end
  
  def make_research_grade_observation(options = {})
    options = {
      :taxon => Taxon.make!(:species), :latitude => 1, :longitude => 1, :observed_on_string => "yesterday"
    }.merge(options)
    o = Observation.make!(options)
    i = Identification.make!(:observation => o, :taxon => o.taxon)
    o.photos << LocalPhoto.make!(:user => o.user)
    Observation.set_quality_grade(o.id)
    o.reload
    o
  end
  
  def make_local_photo(options = {})
    lp = LocalPhoto.make!(options)
    lp.observations << Observation.make!(:user => lp.user)
    lp
  end
  
  def make_project_invitation(options = {})
    pu = ProjectUser.make!
    o = Observation.make!
    pi = ProjectInvitation.create!(options.merge(:user => pu.user, :project => pu.project, :observation => o))
    pi
  end

  def make_project_observation(options = {})
    p = options[:project] || Project.make!
    t = options.delete(:taxon)
    pu = ProjectUser.make!(:project => p)
    o = Observation.make!(:user => pu.user, :taxon => t)
    ProjectObservation.make!({:project => pu.project, :observation => o}.merge(options))
  end
  
  # creating the tree is a bit tricky
  def load_test_taxa
    Rails.logger.debug "\n\n\n[DEBUG] loading test taxa"
    @Life = Taxon.find_by_name('Life') || Taxon.make!(:name => 'Life')

    unless @Animalia = Taxon.iconic_taxa.find_by_name('Animalia')
      @Animalia = Taxon.make!(:name => 'Animalia', :rank => 'kingdom', :is_iconic => true)
    end
    @Animalia.update_attributes(:parent => @Life)

    unless @Chordata = Taxon.iconic_taxa.find_by_name('Chordata')
      @Chordata = Taxon.make!(:name => 'Chordata', :rank => "phylum")
    end
    @Chordata.update_attributes(:parent => @Animalia)

    unless @Amphibia = Taxon.iconic_taxa.find_by_name('Amphibia')
      @Amphibia = Taxon.make!(:name => 'Amphibia', :rank => "class", :is_iconic => true)
    end
    @Amphibia.update_attributes(:parent => @Chordata)

    unless @Hylidae = Taxon.iconic_taxa.find_by_name('Hylidae')
      @Hylidae = Taxon.make!(:name => 'Hylidae', :rank => "order")
    end
    @Hylidae.update_attributes(:parent => @Amphibia)

    unless @Pseudacris = Taxon.iconic_taxa.find_by_name('Pseudacris')
      @Pseudacris = Taxon.make!(:name => 'Pseudacris', :rank => "genus")
    end
    @Pseudacris.update_attributes(:parent => @Hylidae)

    unless @Pseudacris_regilla = Taxon.iconic_taxa.find_by_name('Pseudacris regilla')
      @Pseudacris_regilla = Taxon.make!(:name => 'Pseudacris regilla', :rank => "species")
    end
    @Pseudacris_regilla.update_attributes(:parent => @Pseudacris)

    unless @Aves = Taxon.iconic_taxa.find_by_name('Aves')
      @Aves = Taxon.make!(:name => "Aves", :rank => "class", :is_iconic => true)
    end
    @Aves.update_attributes(:parent => @Chordata)

    unless @Apodiformes = Taxon.iconic_taxa.find_by_name('Apodiformes')
      @Apodiformes = Taxon.make!(:name => "Apodiformes", :rank => "order")
    end
    @Apodiformes.update_attributes(:parent => @Aves)

    unless @Trochilidae = Taxon.iconic_taxa.find_by_name('Trochilidae')
      @Trochilidae = Taxon.make!(:name => "Trochilidae", :rank => "family")
    end
    @Trochilidae.update_attributes(:parent => @Apodiformes)

    unless @Calypte = Taxon.iconic_taxa.find_by_name('Calypte')
      @Calypte = Taxon.make!(:name => "Calypte", :rank => "genus")
    end
    @Calypte.update_attributes(:parent => @Trochilidae)

    unless @Calypte_anna = Taxon.iconic_taxa.find_by_name('Calypte anna')
      @Calypte_anna = Taxon.make!(:name => "Calypte anna", :rank => "species")
      @Calypte_anna.taxon_names << TaxonName.make!(:name => "Anna's Hummingbird", 
        :taxon => @Calypte_anna, 
        :lexicon => TaxonName::LEXICONS[:ENGLISH])
    end
    @Calypte_anna.update_attributes(:parent => @Calypte)

    Rails.logger.debug "[DEBUG] DONE loading test taxa\n\n\n"
  end
end
