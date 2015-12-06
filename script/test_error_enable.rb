
#
# Test for failure when #connect attempts to enter privileged EXEC mode.
#
ASAConsole::Test.script do |asa|
  asa.enable_password = 'bad enable password'

  # The #connect method will time out waiting for a prompt ending in "#" because
  # the next prompt it receives will be a second "Password:" prompt.
  asa.terminal.command_timeout = 1

  log 'Connecting with a bad enable password...'
  asa.connect

  # It won't get this far.
  log 'Disconnecting...'
  asa.disconnect
end
