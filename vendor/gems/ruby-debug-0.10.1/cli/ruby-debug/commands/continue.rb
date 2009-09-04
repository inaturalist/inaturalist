module Debugger
  # Implements debugger "continue" command.
  class ContinueCommand < Command
    self.allow_in_post_mortem = false
    self.need_context         = true
    def regexp
      /^\s* c(?:ont(?:inue)?)? (?:\s+(.*))? $/x
    end

    def execute
      if @match[1] && !@state.context.dead?
        file = File.expand_path(@state.file)
        line = get_int(@match[1], "Continue", 0, nil, 0)
        return unless line
        @state.context.set_breakpoint(file, line)
      end
      @state.proceed
    end

    class << self
      def help_command
        'continue'
      end

      def help(cmd)
        %{
          c[ont[inue]][ nnn]\trun until program ends, hits a breakpoint or reaches line nnn 
        }
      end
    end
  end
end
