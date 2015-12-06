
#
# The connection will fail with a timeout error.
#
ASAConsole::Test.script do |asa|
  asa.terminal.host = '192.0.2.1' # Non-routable IP from RFC 5737

  # We already know it's going to time out so there's no need to wait long.
  asa.terminal.connect_timeout = 1

  log 'Connecting to a non-routable IP...'
  asa.connect

  # It won't get this far.
  log 'Disconnecting...'
  asa.disconnect
end

#
# The connection will fail with an authentication error.
#
ASAConsole::Test.script do |asa|
  asa.terminal.password = 'wrong password'

  log 'Connecting with the wrong password...'
  asa.connect

  # It won't get this far.
  log 'Disconnecting...'
  asa.disconnect
end
