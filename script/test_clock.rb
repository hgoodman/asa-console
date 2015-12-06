
#
# This script demonstrates a method for converting a firewall timestamp to a
# time in the local timezone. We have to explicitly query for the UTC offset
# since the timezone string can be set to any arbitrary value.
#
ASAConsole::Test.script do |asa|
  asa.connect

  log "Local time is #{Time.now}"

  time = ASAConsole::Util.parse_cisco_time(asa.show('clock')) do |t, tz|
    log "Remote time (not adjusted for timezone) is #{t}"
    log "Remote timezone string is #{tz}"

    # We need to use "all clock" instead of "clock" since the timezone line is
    # omitted from default output when using UTC.
    result = asa.running_config('all clock').select('clock timezone').config_data
    matches = /(?<tz>[\S]+) (?<offset>\-?\d+)/.match(result)

    # It's technically possible for the summer time string to match the timezone
    # string, but let's assume this firewall has a sane configuration.
    if tz == matches[:tz]
      log 'Assuming we are not on summer time...'
      offset = matches[:offset].to_i
    else
      log 'Assuming we are on summer time...'
      offset = matches[:offset].to_i + 1
    end

    log "UTC offset is #{offset}"

    t - (offset * 3600) + Time.now.gmt_offset
  end

  log "Remote time (adjusted to the local timezone) is #{time}"

  asa.disconnect
end
