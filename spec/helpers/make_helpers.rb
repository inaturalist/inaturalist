module MakeHelpers
  def make_curator
    make_user_with_role(:curator)
  end
  
  def make_admin
    make_user_with_role(User::JEDI_MASTER_ROLE)
  end
  
  def make_user_with_role(role_name)
    user = User.make
    user.roles << Role.make(:name => role_name.to_s)
    user
  end
  
  def make_life_list_for_taxon(taxon)
    list = LifeList.make
    list.rules << ListRule.new(
      :operand => taxon, 
      :operator => 'in_taxon?'
    )
    list
  end
  
  def make_observation_of_threatened
    Observation.make(
      :latitude => 38.333, :longitude => -122.111,
      :taxon => Taxon.make(:threatened),
      :created_at => Time.now.to_date
    )
  end
  
  # It's important that the lat & lon don't show up in the date when doing 
  # simple regex tests
  def make_private_observation
    Observation.make(:latitude => 38.888, :longitude => -122.222, 
      :geoprivacy => Observation::PRIVATE, 
      :created_at => Time.now.to_date)
  end
end