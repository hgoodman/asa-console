
#
# Test configuring a network object to demonstrate the difference between
# #config_exec! and #config_exec without the "!".
#
ASAConsole::Test.script do |asa|
  asa.connect

  if asa.version? '< 8.3(1)'
    log "Objects are not supported in version #{asa.version}"
  else
    id = 'TestObject-192.0.2.1'

    # This command will return an "ERROR: " message if the object does not
    # already exist, so we need to pass a flag to ignore it.
    asa.config_exec!('no object network ' + id, ignore_errors: true)

    asa.config_exec!('object network ' + id)

    # We are now in a configuration submode.
    asa.config_exec('description My network object', require_config_mode: 'config-network-object')
    asa.config_exec('host 192.0.2.1', require_config_mode: 'config-network-object')

    # There is no "config-object" mode so let's use that to make sure that the
    # config mode requiremnt is actually being checked.
    begin
      asa.config_exec('description Something went wrong', require_config_mode: 'config-object')
    rescue ASAConsole::Error::ConfigModeError => e
      log "Rescued config mode error: #{e.message}"
    end

    rc = asa.running_config('object id ' + id).select('object')
    desc = rc.select('description').config_data
    host = rc.select('host').config_data

    log "Network object #{id} has description #{desc.dump}"
    log "Network object #{id} has host #{host}"

    asa.config_exec!('no object network ' + id)

    rc = asa.running_config('object id ' + id).select('object')
    if rc.nil?
      log "Object #{id} has been removed"
    else
      log "Object #{id} still exists"
    end
  end

  asa.disconnect
end
