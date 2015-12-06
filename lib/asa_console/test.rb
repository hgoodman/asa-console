
require 'asa_console'
require 'asa_console/test/script'

class ASAConsole
  #
  # Methods to declare and execute {ASAConsole} test scripts in a lab
  # environment.
  #
  # @example Contents of `./my_test_file.rb`
  #   ASAConsole::Test.script do |asa|
  #     log 'Connecting...'
  #     asa.connect
  #     log 'Executing the "show failover" command...'
  #     asa.show('failover')
  #     log 'Disconnecting...'
  #     asa.disconnect
  #   end
  #
  # @example Execute scripts in `./my_test_file.rb`
  #   require 'asa_console/test'
  #
  #   terminal_opts = { host: '192.0.2.1', user: 'admin', password: 'secret' }
  #
  #   ASAConsole::Test.color_scheme = :light
  #   ASAConsole::Test.start('./my_test_file.rb', terminal_opts)
  #
  module Test
    #
    # @api private
    @@scripts = []
    #
    # @api private
    @@colors = {}

    # Declare a test script by passing a block to this method.
    #
    # @yieldparam asa [ASAConsole] object to manipulate
    def self.script(&block)
      klass = Class.new(Script)
      klass.send(:define_method, 'test!', &block)
      @@scripts << klass
    end

    # Set the color scheme for test script output.
    #
    # @param scheme_key [Symbol]
    #   `:light` for light (or bold) colors, `:dark` for dark colors. Any other
    #   option prevents colorized output.
    def self.color_scheme=(scheme_key)
      case scheme_key
      when :light
        @@colors = {
          prompt: "\e[1;36m",
          input:  "\e[1;33m",
          output: "\e[1;32m",
          log:    "\e[1;31m",
          info:   "\e[1;35m"
        }
      when :dark
        @@colors = {
          prompt: "\e[0;36m",
          input:  "\e[0;33m",
          output: "\e[0;32m",
          log:    "\e[0;31m",
          info:   "\e[0;35m"
        }
      else
        @@colors = {}
      end
    end

    # @api private
    def self.colorize(str, color_key)
      return str unless @@colors[color_key] && !str.empty?
      @@colors[color_key] + str + "\e[0m"
    end

    # Returns the absolute path of the test script directory or, if a test name
    # is given, returns the path to the test file.
    #
    # @overload test_path
    #   @return [String] the filesystem path of the test script directory
    # @overload test_path(test_name)
    #   @param test_name [String] the test name
    #   @return [String] the filesystem path of the named test script
    # @return [String] a filesystem path
    def self.test_path(test_name = nil)
      path = File.realpath(File.join(File.dirname(__FILE__), '..', '..', 'script'))
      path = File.join(path, "test_#{test_name}.rb") if test_name
      path
    end

    # A list of test names that can be passed to the command line utility.
    #
    # @return [Array]
    def self.test_names
      names = Dir.glob(File.join(test_path, 'test_*.rb'))
      names.collect { |file| file.sub(/.*test_(.*)\.rb$/, '\1') }.sort
    end

    # Load a ruby source file with test script declarations and execute them.
    #
    # The `terminal_opts` and `enable_password` parameters will be passed to a
    # {ASAConsole} factory method to generate a test object for each script run.
    #
    # @param test_file [String]
    # @param terminal_opts [Hash]
    # @param enable_password [String]
    # @param show_session_log [Boolean]
    #   append the session log to the end of each test output if `true`
    # @return [Boolean]
    #   `true` if `test_file` can be loaded with `require`, or `false` otherwise
    def self.start(test_file, terminal_opts, enable_password = nil, show_session_log = false)
      begin
        require test_file
      rescue LoadError
        puts "Unable to load #{test_file}"
        return false
      end

      @@scripts.each do |klass|
        script = klass.new(terminal_opts, enable_password)
        script.run
        script.show_session_log if show_session_log
        puts
        puts colorize('Test Complete!', :info)
        puts
      end

      true
    end
  end
end
