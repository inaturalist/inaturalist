class ControllerStub
  
  attr_writer :params
  def params
    @params||{}
  end
  
  attr_accessor :current_user 
  
  
  
  def self.before_filter(*args)
  end

  def self.helper_method(*args)
  end
#  
#  def access_denied
#    false
#  end

  attr_accessor :render_params
  def render(*params)
    @render_params = params
  end
  
  attr_accessor :redirect_to_params
  def redirect_to(*redirect_to_params)
    @redirect_to_params = redirect_to_params
  end
end