module Debugger
  class CatchCommand < Command # :nodoc:
    self.allow_in_control = true

    def regexp
      /^\s* cat(?:ch)? (?:\s+(.+))? $/x
    end

    def execute
      if excn = @match[1]
        if excn == 'off'
          Debugger.catchpoint = nil
          print "Clear catchpoint.\n"
        else
          binding = @state.context ? get_binding : TOPLEVEL_BINDING
          unless debug_eval("#{excn}.is_a?(Class)", binding)
            print "Warning #{excn} is not known to be a Class\n"
          end
          Debugger.add_catchpoint(excn)
          print "Catch exception %s.\n", excn
        end
      else
        info_catch
      end
    end

    class << self
      def help_command
        'catch'
      end

      def help(cmd)
        %{
          cat[ch]\t\t\tsame as "info catch"
          cat[ch] <exception-name>\tIntercept <exception-name> when there would otherwise be is no handler 
for it.
        }
      end
    end
  end
end
