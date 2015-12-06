
#
# This test will raise a command error.
#
ASAConsole::Test.script do |asa|
  log 'Connecting...'
  asa.connect

  log 'Generating an error...'
  asa.priv_exec('derp derp derp')

  # It won't get this far.
  log 'Disconnecting...'
  asa.disconnect
end
