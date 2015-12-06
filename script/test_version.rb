
#
# Test various methods for checking the ASA software version.
#
ASAConsole::Test.script do |asa|
  asa.connect

  log asa.version?('=7') ? 'This is version 7' : 'This is not version 7'

  log asa.version?('<8') ? 'Version is less than 8' : 'Version is not less than 8'

  if asa.version?('7.x(x)') || asa.version?('<=8.3(x)')
    log 'Running an old version'
  end

  asa.version? '!8.x', '!9.x' do
    log 'Not running version 8 or 9'
  end

  asa.version? '>7', '8.x' do
    log 'Version 8!'
  end

  asa.version? '>7', '9.x' do
    log 'Version 9!'
  end

  log 'Version string is ' + asa.version

  asa.disconnect
end
