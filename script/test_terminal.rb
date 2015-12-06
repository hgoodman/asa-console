
#
# Test the behavior of the running config cache by repeatedly querying for the
# terminal width.
#
ASAConsole::Test.script do |asa|
  asa.connect

  def terminal_width(asa)
    asa.running_config('terminal').select('terminal width').config_data
  end

  # This will send a "show running-config" command to the device.
  tw = terminal_width(asa)
  log "Terminal width is #{tw}"

  asa.config_exec! "terminal width 40"
  log "Terminal width is now #{terminal_width(asa)}"     # This will send another "show running-config".
  asa.config_exec! "terminal width #{tw}"
  log "Terminal width is back to #{terminal_width(asa)}" # This will send another "show running-config".
  log "Checking again..."
  log "Terminal width is still #{terminal_width(asa)}"   # This time the value will be pulled from the cache.

  asa.disconnect
end
