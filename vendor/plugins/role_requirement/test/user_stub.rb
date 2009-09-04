class User
  attr_accessor :roles
  
  def id
    1
  end
  
  def initialize(params = {})
    self.roles = params[:roles]
  end
  
  def has_role?(role)
    return @roles.include?(role)
  rescue
    false
  end
  
  attr_reader :roles
  
  def roles=(value)
    if Array===value
      @roles = value 
    elsif String===value
      @roles = value.split(",")
    else
      @roles = nil
    end
  end
  
end