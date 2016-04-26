
require 'asa_console/config'
require 'asa_console/error'
require 'asa_console/terminal/fake_ssh'
require 'asa_console/terminal/ssh'

#
# Command line interface to a Cisco ASA.
#
# @example
#   # Create an instance of ASAConsole for an SSH connection
#   asa = ASAConsole.ssh(
#     host: 'fw01.example.com', # Required by Net::SSH
#     user: 'admin',            # Required by Net::SSH
#     password: 'mypass',       # Optional in case you want to use SSH keys
#     connect_timeout: 3,       # Converted to the Net::SSH :timeout value
#     command_timeout: 10,      # How long to wait for a command to execute?
#     enable_password: 'secret' # Optional if it's the same as :password
#   )
#
#   # Other Net::SSH options can be set before connecting
#   asa.terminal.ssh_opts[:port] = 2022
#
#   asa.connect
#   puts asa.show('version')
#   asa.disconnect
#
# @attr_reader config_mode [String, nil]
#   Configuration submode string (e.g. "config", "config-if") or `nil` if not
#   in a configuration mode
# @attr terminal [Object]
#   An instance of a class from the {Terminal} module
# @attr enable_password [String, nil]
#   Enable password or `nil` if the enble password is not required
#
class ASAConsole
  attr_reader :config_mode
  attr_accessor :terminal
  attr_accessor :enable_password

  PASSWORD_PROMPT   = /^Password: +\z/
  EXEC_PROMPT       = /^[\w\.\/-]+> +\z/
  PRIV_EXEC_PROMPT  = /^[\w\.\/-]+(?:\(config[\s\w-]*\))?# +\z/
  ANY_EXEC_PROMPT   = /^[\w\.\/-]+(?:(?:\(config[\s\w-]*\))?#|>) +\z/
  CONFIG_PROMPT     = /^[\w\.\/-]+\(config[\s\w-]*\)# +\z/
  INVALID_CMD_CHAR  = /[^\x20-\x3e\x40-\x7e]/
  CONFIG_MODE_REGEX = /^[\w\.\-\/]+\((config[\s\w\-]*)\)# $/
  CMD_ERROR_REGEX   = /^ERROR: (?:% )?(.*)/

  class << self
    # Factory method for a fake SSH console session.
    #
    # @api development
    # @see Terminal::FakeSSH#initialize Terminal::FakeSSH constructor
    # @option opts ... options for the {Terminal::FakeSSH} constructor
    # @option opts [String] :enable_password
    # @return [ASAConsole]
    def fake_ssh(opts)
      enable_password = opts.delete(:enable_password)
      terminal = Terminal::FakeSSH.new(opts)
      new terminal, enable_password
    end

    # Factory method for an SSH console session.
    #
    # @see Terminal::SSH#initialize Terminal::SSH constructor
    # @option opts ... options for the {Terminal::SSH} constructor
    # @option opts [String] :enable_password
    # @return [ASAConsole]
    def ssh(opts)
      enable_password = opts.delete(:enable_password)
      terminal = Terminal::SSH.new(opts)
      new terminal, enable_password
    end

    private :new
  end

  # @private
  def initialize(terminal, enable_password = nil)
    @config_mode = nil
    @terminal = terminal
    @terminal.on_output do
      matches = CONFIG_MODE_REGEX.match(@terminal.prompt)
      @config_mode = matches ? matches[1] : nil
    end
    @enable_password = enable_password
    @version = nil
    @running_config = {}
  end

  # @return [void]
  def connect
    @terminal.connect
    priv_exec! 'terminal pager lines 0'
  end

  # @return [Boolean]
  def connected?
    @terminal.connected?
  end

  # @return [void]
  def disconnect
    while @terminal.connected? && @terminal.prompt =~ ANY_EXEC_PROMPT
      @terminal.send('exit', ANY_EXEC_PROMPT) { |success| break unless success }
    end
    @terminal.disconnect
  end

  # Send a line of text to the console and block until the expected prompt is
  # seen in the output or a timeout is reached. Raises an exception if the
  # expected prompt has not been received after waiting for `command_timeout`
  # seconds following the last data transfer.
  #
  # @param line [String]
  # @param expect_regex [Regexp]
  # @param is_password [Boolean]
  #   if `true`, `line` will be masked with asterisks in the session log
  # @raise [Error::ExpectedPromptFailure]
  # @return [String] output from the command, if any
  def send(line, expect_regex, is_password = false)
    must_be_connected!
    line = line.gsub(INVALID_CMD_CHAR, "\x16\\0") unless is_password
    @terminal.send(line, expect_regex, is_password) do |success, output|
      fail Error::ExpectedPromptFailure, "Expected prompt not found in output: #{output}" unless success
      output
    end
  end

  # Execute a command in any configuration mode.
  #
  # @param command [String]
  # @option opts [Regexp] :expect_prompt
  #   prompt expected after executing the command
  # @option opts [Boolean] :ignore_output
  #   if `true`, do not raise an error when the command generates output (unless
  #   the output is an error message)
  # @option opts [Boolean] :ignore_errors
  #   if `true`, ignore error messages in the output (implies `:ignore_output`)
  # @option opts [Boolean] :require_config_mode
  #   a specific configuration submode required to execute the command
  # @return [String] output from the command, if any
  def config_exec(command, opts = {})
    must_be_connected!
    enable! if @terminal.prompt =~ EXEC_PROMPT

    expect_prompt = opts.fetch(:expect_prompt, CONFIG_PROMPT)
    ignore_output = opts.fetch(:ignore_output, false)
    ignore_errors = opts.fetch(:ignore_errors, false)
    require_config_mode = opts[:require_config_mode]

    unless @terminal.prompt =~ CONFIG_PROMPT
      send('configure terminal', CONFIG_PROMPT)
    end

    if require_config_mode && @config_mode != require_config_mode
      message = "Will not execute command in '%s' mode (expected '%s')"
      fail Error::ConfigModeError, message % [ @config_mode, require_config_mode ]
    end

    # Any part of the config may change, so clear the cache.
    @running_config = {}

    output = send(command, expect_prompt)

    unless ignore_errors
      error = CMD_ERROR_REGEX.match(output)
      fail Error::CommandError, "Error output after executing '#{command}': #{error[1]}" if error
      unless ignore_output || output.empty?
        fail Error::UnexpectedOutputError, "Unexpected output after executing '#{command}': #{output}"
      end
    end

    output
  end

  # Execute a command from top-level configuration mode. This method is a
  # wrapper for {#config_exec}.
  #
  # @see #config_exec
  # @param command [String]
  # @param opts [Hash] options for {#config_exec}
  # @return [String] output from the command, if any
  def config_exec!(command, opts = {})
    must_be_connected!
    send('exit', CONFIG_PROMPT) while @config_mode && @config_mode != 'config'
    config_exec(command, opts)
  end

  # Execute a command in any privileged EXEC mode (includes config EXEC modes).
  #
  # @param command [String]
  # @return [String] output from the command, if any
  def priv_exec(command)
    must_be_connected!
    enable! if @terminal.prompt =~ EXEC_PROMPT
    last_prompt = @terminal.prompt
    output = send(command, PRIV_EXEC_PROMPT)

    # A prompt change may indicate a context switch or other event that would
    # invalidate the config cache.
    @running_config = {} if @terminal.prompt != last_prompt

    error = CMD_ERROR_REGEX.match(output)
    fail Error::CommandError, "Error output after executing '#{command}': #{error[1]}" if error
    output
  end

  # Execute a command in privileged EXEC mode (excludes config EXEC modes). This
  # method is a wrapper for {#priv_exec}.
  #
  # @see #priv_exec
  # @param command [String]
  # @return [String] output from the command, if any
  def priv_exec!(command)
    must_be_connected!
    send('exit', PRIV_EXEC_PROMPT) while @config_mode
    priv_exec(command)
  end

  # A shortcut for running "show" commands.
  #
  # @param subcmd [String]
  # @return [String]
  def show(subcmd)
    priv_exec('show ' + subcmd)
  end

  # Execute a "show running-conifg [...]" command and load the results into a
  # {Config} object.
  #
  # @see Config
  # @param subcmd [String, nil]
  # @return [Config] a top-level {Config} node with nested config
  def running_config(subcmd = nil)
    unless @running_config.key? subcmd
      output = subcmd ? show('running-config ' + subcmd) : show('running-config')
      @running_config[subcmd] = Config.new(nested_config: output)
    end
    @running_config[subcmd]
  rescue Error::CommandError
    Config.new
  end

  # ASA software version in `x.x(x)` format.
  #
  # @return [String]
  def version
    unless @version
      # Reassemble the version string on the off chance that an interim release
      # is reported in the format "x.x(x.x)" versus "x.x(x)x".
      regex = /^Cisco Adaptive Security Appliance Software Version (\d+)\.(\d+)\((\d+).*?\)/
      matches = regex.match(show('version'))
      fail Error::VersionParseError, 'Unable to determine appliance version' unless matches
      @version = '%d.%d(%d)' % matches[1..3]
    end
    @version
  end

  # Return the result of comparing the ASA software version with a list of
  # expressions. Will `yield` once on success if a block is given.
  #
  # @example
  #   asa.version? '9.x', '< 9.3' do
  #     puts 'Running version 9.0, 9.1 or 9.2'
  #   end
  #
  # @see Util.version_match? The utility function called by this method
  # @param exprs [Array<String>]
  # @return [Boolean] `true` if _all_ expressions match, or `false` otherwise
  def version?(*exprs)
    success = Util.version_match?(version, exprs)
    yield if success && block_given?
    success
  end

  def enable!
    send('enable', PASSWORD_PROMPT)
    password = @enable_password ? @enable_password : @terminal.password
    send(password, PRIV_EXEC_PROMPT, true)
  end
  private :enable!

  def must_be_connected!
    fail Error::NotConnectedError, 'Terminal is not connected' unless @terminal.connected?
  end
  private :must_be_connected!
end
