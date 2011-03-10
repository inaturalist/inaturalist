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
end