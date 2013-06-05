#
# Module for ActiveRecord model adapters.
#
# Usage:
#   class YourModelAdapter
#     include ModelAdapter
#     alias :your_model :adaptee # optional
#     
#     def initialize
#       @adaptee = YourModel.new # required!
#     end
#     
#     def some_attribute
#       do_something_different
#     end
#   end
#
module ModelAdapter
  attr_accessor :adaptee
  
  def method_missing(method, *args)
    if @adaptee.respond_to? method
      @adaptee.send(method, *args)
    else
      raise NoMethodError, "#{self.class} hasn't implemented #{method}"
    end
  end
  
  # Redirect calls to public methods in Object to the adaptee
  Object.methods.each do |method_name|
    define_method(method_name.to_sym) do |*args|
      @adaptee.send(method_name.to_sym, *args)
    end
  end
  
  #
  # Fetch the logger of the adaptee so adapters can access the Rails logger
  #
  def logger
    @adaptee.logger
  end
end