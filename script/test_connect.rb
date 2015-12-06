
#
# A simple connection test.
#
ASAConsole::Test.script do |asa|
  log 'Connecting...'
  asa.connect
  log 'Disconnecting...'
  asa.disconnect
end
