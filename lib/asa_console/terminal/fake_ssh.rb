
require 'asa_console/terminal/ssh'

class ASAConsole
  module Terminal
    #
    # A subclass of {SSH} that overrides the {SSH#connect} method to generate
    # stub objects for RSpec testing.
    #
    # The constructor takes the same hash options as {SSH#initialize}, but
    # requires one additional option; `:input_proc`, a proc that takes two
    # arguments:
    #   * `input` -- A command or other input that is being passed to the
    #     simulated appliance.
    #   * `prompt` -- Last prompt displayed on the terminal when the `input`
    #     text was entered.
    #
    # The proc is expected to return an array with three elements:
    #   * `output` -- Result of sending `input` to the simulated appliance.
    #   * `prompt` -- Next prompt to present within the session.
    #   * `disconnect` -- `true` to indicate that the SSH connection has been
    #     closed (e.g. if "exit" was sent to the terminal), or `false`
    #     otherwise.
    #
    # @example
    #   input_proc = proc do |input|
    #     prompt = 'TEST# '
    #     case input
    #     when "terminal pager lines 0\n", nil
    #       output = prompt
    #       disconnect = false
    #     when "exit\n"
    #       output = "\nLogoff\n\n"
    #       disconnect = true
    #     else
    #       output = "ERROR: Command not implemented\n" + prompt
    #       disconnect = false
    #     end
    #     [output, prompt, disconnect]
    #   end
    #
    #   asa = ASAConsole.fake_ssh(
    #     host: 'ignored',
    #     user: 'ignored',
    #     input_proc: input_proc
    #   )
    #   asa.connect
    #
    #   # This will raise an error
    #   asa.priv_exec('write memory')
    #
    # @api development
    class FakeSSH < SSH
      #
      # @api private
      attr_accessor :raw_buffer
      #
      # @api private
      attr_accessor :raw_session_log
      #
      # @api private
      attr_accessor :session
      #
      # @api private
      attr_accessor :channel
      #
      # @api private
      attr_accessor :last_output_received
      #
      # @api private
      attr_accessor :input_proc

      # Wrapper for the {SSH} class constructor that extracts `:input_proc` from
      # the options hash and passes the rest to the parent.
      #
      # @option opts [Proc] :input_proc
      # @option opts ... options for the {SSH} constructor
      # @see SSH#initialize SSH constructor
      def initialize(opts)
        @input_proc = opts.delete(:input_proc)
        fail Error::MissingOptionError, 'Option :input_proc is missing or invalid' \
          unless @input_proc.is_a? Proc
        super(opts)
      end

      # Connect to a simulated appliance. This method creates anonymous stub
      # classes that take the place of `Net::SSH::Connection::Session` and
      # `Net::SSH::Connection::Channel`. The stub classes implement only the
      # subset of methods that are used by the {SSH} terminal class.
      #
      # @return [void]
      def connect
        @session = Class.new do
          def initialize
            @closed = false
          end
          def close
            @closed = true
          end
          def closed?
            @closed ? true : false
          end
        end.new

        @channel = Class.new do
          attr_reader :terminal
          def initialize(terminal)
            @terminal = terminal
            @input_buffer = ''
            @output_buffer, @prompt = @terminal.input_proc.call
          end
          def connection
            self
          end
          def process(timeout)
            sleep timeout
            @terminal.raw_buffer = @output_buffer
            @terminal.raw_session_log << @output_buffer
            @output_buffer = ''
            fail Net::SSH::Disconnect if @terminal.session.closed?
          end
          def send_data(input)
            @input_buffer << input
            return unless @input_buffer.end_with? "\n"
            @output_buffer << @input_buffer
            output, prompt, disconnect = @terminal.input_proc.call(@input_buffer, @prompt)
            @output_buffer << output
            @prompt = prompt
            @terminal.session.close if disconnect
            @input_buffer = ''
            @terminal.last_output_received = Time.now
          end
        end.new(self)

        @connected = true

        # This is copied verbatim from the parent #connect method
        expect(ANY_EXEC_PROMPT) do |success, output|
          @on_output_callbacks.each { |c| c.call(nil, nil, output) }
          fail Error::ConnectFailure 'Failed to parse EXEC prompt', self unless success
        end
      end
    end
  end
end
