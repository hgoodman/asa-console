
class ASAConsole
  module Test
    #
    # Parent class for {ASAConsole} test scripts.
    #
    class Script
      # @private
      def initialize(terminal_opts, enable_password = nil)
        @asa = ASAConsole.ssh(terminal_opts)
        @asa.enable_password = enable_password if enable_password
        @asa.terminal.on_output do |prompt, input, output|
          print Test.colorize(prompt, :prompt) if prompt
          print Test.colorize(input, :input) if input
          print Test.colorize(output, :output) if output
        end
      end

      # @api private
      def run
        test! @asa
      rescue Exception => e
        puts
        puts Test.colorize('Received Exception:', :info)
        puts '  ' + e.class.name
        puts Test.colorize('Message:', :info)
        puts '  ' + e.message
        puts Test.colorize('Stack Trace:', :info)
        puts e.backtrace.join("\n").gsub(/^/, '  ')
      end

      # @api private
      def show_session_log
        puts Test.colorize('Session Log:', :info)
        puts @asa.terminal.session_log.gsub(/^/, '  ').chomp
        puts
      end

      # Call from within a {script} block to output status messages.
      #
      # @see script
      # @param text [String]
      def log(text)
        puts Test.colorize(text, :log)
      end
    end
  end
end
