module Debugger
  class MethodCommand < Command # :nodoc:
    def regexp
      /^\s*m(?:ethod)?\s+((iv)|(i(:?nstance\s+)?)\s+)?/
    end

    def execute
      if @match[1] == "iv"
        obj = debug_eval(@match.post_match)
        obj.instance_variables.sort.each do |v|
          print "%s = %s\n", v, obj.instance_variable_get(v).inspect
        end
      elsif @match[1]
        obj = debug_eval(@match.post_match)
        print "%s\n", columnize(obj.methods.sort(), 
                                self.class.settings[:width])
      else
        obj = debug_eval(@match.post_match)
        unless obj.kind_of? Module
          print "Should be Class/Module: %s\n", @match.post_match
        else
          print "%s\n", columnize(obj.instance_methods(false).sort(), 
                                  self.class.settings[:width])
        end
      end
    end

    class << self
      def help_command
        'method'
      end

      def help(cmd)
        %{
          m[ethod] i[nstance] <obj>\tshow methods of object
          m[ethod] iv <obj>\tshow instance variables of object
          m[ethod] <class|module>\t\tshow instance methods of class or module
        }
      end
    end
  end
end
