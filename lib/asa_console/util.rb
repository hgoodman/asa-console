
require 'stringio'
require 'asa_console/error'

class ASAConsole
  #
  # Miscellaneous utility functions.
  #
  module Util
    CISCO_TIME_REGEX = %r{
      (?<hour> \d\d):
      (?<min> \d\d):
      (?<sec> \d\d)
      (?:\.(?<subsec> \d\d\d)\s)?
      (?<tz> .*?)\s
      (?:(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s)?
      (?<month> \w\w\w)\s
      (?<day> \d\d?)\s
      (?<year> \d\d\d\d)
    }x

    VERSION_EXPR_REGEX = %r{^
      (?<opr> [><=!]=?)?\s*     # Comparison operator
      (?<major> \d+) (?:        # Major release number
        \.(?<minor> \d+|x) (?:  # Minor release number or x
           \((?<maint> \d+|x)\) # Maintenance release number or x
        )?
      )?
    $}x

    # Convert a string with terminal control characters to plain text as it
    # would appear in a terminal window.
    #
    # An ASA will use backspaces and carriage returns to hide text that has
    # already been output to the console. For example, the ASA outputs extra
    # characters to hide the `<--- More --->` prompt when the user presses a
    # key.
    #
    # @param raw [String]
    # @return [String]
    def self.apply_control_chars(raw)
      output = ''
      raw.split("\n").each do |line|
        io = StringIO.new
        line.scan(/([^\r\x08]+|[\r\x08])/) do |m|
          case m[0]
          when "\r"
            io.rewind
          when "\x08"
            io.pos = io.pos - 1
          else
            io.write(m[0])
          end
        end
        output << io.string << "\n"
      end
      output.chop! unless raw.end_with?("\n")
      output.delete("\x00")
    end

    # Parse the time format commonly used in various command output. This can be
    # useful for things like extracting the configuration modification time from
    # "show version" output or for parsing the last failover time.
    #
    # @note
    #   It is not possible to reliably evaluate the timezone string without
    #   running additional commands, so this function (optimistically) returns
    #   a UTC timestamp. See {file:script/test_clock.rb} for one method of
    #   adjusting a remote timestamp to local time using "show clock" commands.
    #
    # @param str [String]
    # @yieldparam time [Time]
    # @yieldparam tz [String]
    #   timezone string set by "clock timezone" or "clock summer-time"
    # @return [Time]
    #   time represented in UTC
    def self.parse_cisco_time(str)
      m = CISCO_TIME_REGEX.match(str)
      return nil unless m
      tz      = m[:tz]
      year    = m[:year].to_i
      month   = m[:month]
      day     = m[:day].to_i
      hour    = m[:hour].to_i
      min     = m[:min].to_i
      sec     = m[:sec].to_i
      subsec  = "0.#{m[:subsec]}".to_f
      time = Time.utc(year, month, day, hour, min, sec) + subsec
      time = yield(time, tz) if block_given?
      time
    end

    # Match an ASA software version string in `x.x(x)` format against one or
    # more conditional expressions.
    #
    # @see #version? The ASAConsole wrapper for this function
    # @param version [String]
    # @param exprs [Array<String>]
    # @return [Boolean] `true` if _all_ expressions match, or `false` otherwise
    def self.version_match?(version, exprs)
      ver = []
      version_match_parse(version) { |_opr, pattern| ver = pattern }
      exprs.each do |e|
        version_match_parse(e) do |opr, pattern|
          return false unless version_match_compare(opr, ver, pattern)
        end
      end
      true
    end

    # @api private
    def self.version_match_parse(expr)
      expr = expr.to_s # Forgive users who provide a number instead of a string
      m = VERSION_EXPR_REGEX.match(expr)
      fail Error::InvalidExpressionError, "Expression '#{expr}' is not valid" unless m
      opr = m[:opr]
      opr = '==' if opr == '=' || opr.nil? # Equality is the default operator
      opr = '!=' if opr == '!'
      pattern = [ m[:major].to_i ]
      if m[:minor] && m[:minor] != 'x'
        pattern << m[:minor].to_i
        pattern << m[:maint].to_i if m[:maint] && m[:maint] != 'x'
      end
      yield(opr, pattern)
    end

    # @api private
    def self.version_match_compare(opr, ver, pattern)
      a = ver[0..(pattern.length - 1)]
      b = pattern.clone
      eq = true
      gt = lt = false
      a.each do |x|
        y = b.shift
        next if x == y
        eq = false
        gt = x > y
        lt = x < y
        break
      end
      case opr
      when '>'  then gt
      when '<'  then lt
      when '==' then eq
      when '>=' then gt || eq
      when '<=' then lt || eq
      when '!=' then !eq
      end
    end
  end
end
