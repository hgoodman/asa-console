
require 'net/ssh'
require 'asa_console/error'
require 'asa_console/terminal'
require 'asa_console/util'

class ASAConsole
  module Terminal
    #
    # An SSH terminal session.
    #
    # @attr host [String]
    #   Hostname or IP address.
    # @attr user [String]
    #   SSH username.
    # @attr password [String]
    #   SSH password.
    # @attr ssh_opts [Hash]
    #   Option hash passed to `Net::SSH::start`.
    # @attr command_timeout [Numeric]
    #   Maximum time to wait for a command to execute.
    # @attr connect_timeout [Numeric]
    #   SSH connection timeout. (`:timeout` option passed to `Net::SSH::start`)
    # @attr_reader prompt [String, nil]
    #   Prompt currently displayed on the terminal or `nil` if not connected.
    #
    class SSH
      DEFAULT_CONNECT_TIMEOUT = 5
      DEFAULT_COMMAND_TIMEOUT = 5

      attr_accessor :host
      attr_accessor :user
      attr_accessor :ssh_opts
      attr_accessor :command_timeout

      attr_reader :prompt

      # @see Terminal
      # @option opts [String] :host
      # @option opts [String] :user
      # @option opts [String] :password
      # @option opts [Numeric] :connect_timeout
      # @option opts [Numeric] :command_timeout
      def initialize(opts)
        fail Error::MissingOptionError, 'Option :host is missing' unless opts[:host]
        fail Error::MissingOptionError, 'Option :user is missing' unless opts[:user]

        @host = opts[:host]
        @user = opts[:user]
        @ssh_opts = {
          timeout: opts.fetch(:connect_timeout, DEFAULT_CONNECT_TIMEOUT),
          number_of_password_prompts: 0 # Avoid prompting for password on authentication failure
        }
        self.password = opts[:password]
        @command_timeout = opts.fetch(:command_timeout, DEFAULT_COMMAND_TIMEOUT)
        @prompt = nil

        @raw_buffer           = ''
        @raw_session_log      = ''
        @connected            = false
        @channel              = nil
        @session              = nil
        @last_output_received = nil
        @on_output_callbacks  = []
      end

      def password
        @ssh_opts[:password]
      end

      def password=(str)
        @ssh_opts[:password] = str
        @ssh_opts[:auth_methods] = ['password'] if str
      end

      def connect_timeout
        @ssh_opts[:timeout]
      end

      def connect_timeout=(timeout)
        @ssh_opts[:timeout] = timeout
      end

      # Start an SSH session and send a remote shell request. The method blocks
      # until an EXEC prompt is received or a timeout is reached.
      #
      # @see https://tools.ietf.org/html/rfc4254 RFC 4254
      # @raise [Error::ConnectFailure] for all error types
      # @raise [Error::AuthenticationFailure]
      #   subclass of {Error::ConnectFailure}
      # @raise [Error::ConnectionTimeoutError]
      #   subclass of {Error::ConnectFailure}
      # @return [void]
      def connect
        Net::SSH.start(@host, @user, @ssh_opts) do |session|
          @session = session
          @session.open_channel do |channel|
            channel.send_channel_request('shell') do |ch, ch_success|
              fail Error::ConnectFailure, 'Failed to start remote shell' unless ch_success
              @connected = true
              @channel = ch
              @channel.on_data do |_ch, data|
                @last_output_received = Time.now.getlocal
                @raw_session_log << data
                @raw_buffer << data
              end
              @channel.on_close do
                @connected = false
              end
              expect(ANY_EXEC_PROMPT) do |success, output|
                @on_output_callbacks.each { |c| c.call(nil, nil, output) }
                fail Error::ConnectFailure, 'Failed to parse EXEC prompt', self unless success
              end
              return # Workaround for Net::SSH limitations borrowed from Puppet
            end
          end
        end
      rescue Timeout::Error
        raise Error::ConnectionTimeoutError, "Timeout connecting to #{@host}"
      rescue Net::SSH::AuthenticationFailed
        raise Error::AuthenticationFailure, "Authentication failed for #{@user}@#{@host}"
      rescue SystemCallError, SocketError => e
        raise Error::ConnectFailure, "#{e.class}: #{e.message}"
      end

      # @return [Boolean]
      def connected?
        @connected = false if @session.nil? || @session.closed?
        @connected
      end

      # @return [void]
      def disconnect
        @session.close if connected?
      rescue Net::SSH::Disconnect
        @session = nil
      end

      # Send a line of text to the console and block until the expected prompt
      # is seen in the output or a timeout is reached.
      #
      # @note
      #   Special characters are not escaped by this method. Use the
      #   {ASAConsole} wrapper for unescaped text.
      #
      # @see ASAConsole#send ASAConsole wrapper for this method
      # @param line [String]
      # @param expect_regex [Regexp]
      # @param is_password [Boolean]
      # @yieldparam success [Boolean]
      # @yieldparam output [String]
      # @return [void]
      def send(line, expect_regex, is_password = false)
        last_prompt = @prompt
        @channel.send_data "#{line}\n" if connected?
        input = (is_password ? '*' * line.length : line) + "\n"
        expect(expect_regex) do |success, output|
          output = output.sub(/^[^\n]*\n/m, '') # Remove echoed input
          @on_output_callbacks.each { |c| c.call(last_prompt, input, output) }
          yield(success, output)
        end
      end

      # Register a proc to be called whenever the {#send} method finishes
      # processing a transaction (whether successful or not).
      #
      # @example
      #   @command_log = []
      #   asa.terminal.on_output do |prompt, command, output|
      #     if prompt && prompt !~ ASAConsole::PASSWORD_PROMPT
      #       @command_log << command
      #     end
      #   end
      #
      # @yieldparam prompt [String]
      # @yieldparam command [String]
      # @yieldparam output [String]
      # @return [void]
      def on_output(&block)
        @on_output_callbacks << block
      end

      # @return [String] a complete log of the SSH session
      def session_log
        Util.apply_control_chars(@raw_session_log)
      end

      def buffer
        Util.apply_control_chars(@raw_buffer)
      end
      protected :buffer

      def expect(prompt_regex)
        @last_output_received = Time.now.getlocal

        while buffer !~ prompt_regex
          begin
            @channel.connection.process(0.1)
            break if Time.now.getlocal - @last_output_received > @command_timeout
          rescue Net::SSH::Disconnect, IOError
            @connected = false
            break
          end
        end

        matches = prompt_regex.match(buffer)
        if matches.nil?
          success = false
          @prompt = nil
        else
          success = true
          @prompt = matches[0]
        end

        output = buffer.sub(prompt_regex, '')
        @raw_buffer = ''

        yield(success, output)
      end
      protected :expect
    end
  end
end
