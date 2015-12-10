
require 'stringio'

class ASAConsole
  #
  # A parser for ASA running/startup config.
  #
  # Each instance represents a single config entry which may include nested
  # lines of config that can be queried with {#select} or {#select_all}.
  #
  # @example Print ACEs with line numbers for each access list
  #   # Start by fetching a top-level Config object
  #   config = asa.running_config('access-list')
  #   config.names_of('access-list').each do |acl|
  #     puts "Access list #{acl}:"
  #     counter = 0
  #     config.select('access-list', acl) do |ace|
  #       counter += 1
  #       puts " Line #{counter}: #{ace.line}"
  #     end
  #     puts
  #   end
  #
  # @example List all interfaces that participate in EIGRP
  #   # Start by fetching a top-level Config object
  #   config = asa.running_config('all router eigrp')
  #   router = config.select('router eigrp')
  #   router.select('passive-interface') do |passive_interface|
  #     ifname = passive_interface.config_data
  #     next if ifname == 'default'
  #     if passive_interface.negated?
  #       puts "Interface '#{ifname}' is sending routing updates"
  #     else
  #       puts "Interface '#{ifname}' is passive"
  #     end
  #   end if router
  #
  # @attr_reader keystr [String, nil]
  #   Key used to select the line of config represented by this object, or `nil`
  #   if the object contains nested top-level config.
  # @attr_reader config_name [String, nil]
  #   An identifier, such as an access list name, used to distinguish between
  #   config entries of the same type.
  # @attr_reader config_data [String, nil]
  #   Remainder of the config line following the {#keystr} and {#config_name}.
  #
  class Config
    attr_reader :keystr
    attr_reader :config_name
    attr_reader :config_data

    # @see #running_config
    # @option opts [String] :keystr class attribute
    # @option opts [String] :config_name class attribute
    # @option opts [String] :config_data class attribute
    # @option opts [Boolean] :negated
    #   `true` if the config line began with "no", or `false` otherwise
    # @option opts [String] :nested_config
    #   a multiline string of config (indentation stripped)
    def initialize(opts = {})
      @keystr         = opts[:keystr]
      @config_name    = opts[:config_name]
      @config_data    = opts[:config_data]
      @negated        = opts.fetch(:negated, false)
      @nested_config  = opts.fetch(:nested_config, '')
    end

    # @return [String, nil]
    #   the selected line, or `nil` if this is a top-level object
    def line
      parts = []
      parts << 'no' if @negated
      parts << @keystr if @keystr
      parts << @config_name if @config_name
      parts << @config_data if @config_data
      parts.empty? ? nil : parts.join(' ')
    end

    # @return [Boolean]
    #   `true` if the selected line began with "no", or `false` otherwise
    def negated?
      @negated ? true : false
    end

    # @return [Boolean]
    #   `true` if there is no nested config, or `false` otherwise
    def empty?
      @nested_config.empty?
    end

    # Select all lines of nested config. Equivalent to {#select} with no
    # arguments.
    #
    # @yieldparam config [Config]
    # @yieldreturn [nil] if a block is given
    # @return [Array<Config>] if no block given
    def select_all
      result = []
      select do |config|
        if block_given?
          yield config
        else
          result << config
        end
      end
      result unless block_given?
    end

    # Select the first matching line of the nested config or `yield` all
    # matching lines if a block is given.
    #
    # @param keystr [String, nil]
    # @param config_name [String, nil]
    # @yieldparam config [Config]
    # @yieldreturn [nil] if a block is given
    # @return [Config] if no block given
    def select(keystr = nil, config_name = nil)
      prefix = [keystr, config_name].join(' ').strip
      regex = /^(?<no>no )?#{Regexp.escape(prefix)} ?(?<data>.+)?/

      io = StringIO.open(@nested_config)
      lines = io.readlines
      io.close

      loop do
        break if lines.empty?

        m = regex.match(lines.shift)
        next unless m

        nested_config = ''
        loop do
          break unless lines[0] && lines[0].start_with?(' ')
          nested_config << lines.shift.sub(/^ /, '')
        end

        config = Config.new(
          keystr:         keystr,
          config_name:    config_name,
          config_data:    m[:data],
          negated:        !m[:no].nil?,
          nested_config:  nested_config
        )

        if block_given?
          yield config
        else
          return config
        end
      end

      nil
    end

    # @see #select
    # @param keystr [String]
    # @return [Array<String>]
    #   a unique list of config element names matched by `keystr`
    def names_of(keystr)
      names = []
      regex = /^(?:no )?#{Regexp.escape(keystr)} (?<name>\S+)/
      @nested_config.each_line do |line|
        m = regex.match(line)
        next unless m
        names << m[:name] unless names.include? m[:name]
      end
      names
    end
  end
end
