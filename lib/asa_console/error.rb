
class ASAConsole
  # Parent class for all other {ASAConsole} exceptions.
  class Exception < ::RuntimeError; end

  # Container for exceptions to avoid cluttering the namespace.
  module Error
    # Raised when an unexpected "ERROR: [...]" message is received.
    class CommandError < Exception; end

    # Raised when attempting to execute a configuration command in the wrong
    # config mode or submode.
    class ConfigModeError < Exception; end

    # Any type of connection failure.
    class ConnectFailure < Exception; end

    # Raised when a terminal object times out waiting for an expected prompt.
    class ExpectedPromptFailure < Exception; end

    # Raised when checking an ASA version against an unsupported expression.
    class InvalidExpressionError < Exception; end

    # Raised when a required option hash entry is missing.
    class MissingOptionError < Exception; end

    # Raised when attempting to execute a command on a disconnected terminal.
    class NotConnectedError < Exception; end

    # Raised (by default) when a configuration command generates output instead
    # of just presenting the next config prompt.
    class UnexpectedOutputError < Exception; end

    # Raised when there is a failure parsing the appliance version string.
    class VersionParseError < Exception; end

    # A {ConnectFailure} caused by invalid credentials.
    class AuthenticationFailure < ConnectFailure; end

    # A {ConnectFailure} caused by a timeout.
    class ConnectionTimeoutError < ConnectFailure; end
  end
end
