
#
# Test configuring IP to name mappings.
#
ASAConsole::Test.script do |asa|
  asa.connect

  def reset_test(asa)
    rc = asa.running_config('names').select('name', '192.0.2.1')
    asa.config_exec!('no name 192.0.2.1') unless rc.nil?
    rc = asa.running_config('names').select('name', '192.0.2.2')
    asa.config_exec!('no name 192.0.2.2') unless rc.nil?
  end

  reset_test(asa)

  # Are question marks being escaped?
  asa.config_exec!("name 192.0.2.1 ASATest1 description What's in a name? That which we call a rose...")
  asa.config_exec!("name 192.0.2.2 ASATest2")

  asa.running_config('names').select('name') do |rc|
    m = /(?<addr>[\d\.]+) (?<name>[\w\-]+)(?: description (?<desc>.*))?/.match(rc.config_data)
    if m[:desc]
      log "#{m[:addr]} is called \"#{m[:name]}\" and its description is \"#{m[:desc]}\""
    else
      log "#{m[:addr]} is called \"#{m[:name]}\" and it has no description"
    end
  end

  reset_test(asa)

  asa.disconnect
end
