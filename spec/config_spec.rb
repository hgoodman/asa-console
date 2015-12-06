
require 'spec_helper'
require 'asa_console/config'

RSpec.describe ASAConsole::Config do

  before :context do
    @fake_config = %(
    : Saved
    :
    ASA Version 7.3(0)
    !
    terminal width 511
    hostname TEST
    names
    name 10.1.1.100 LANHost
    name 10.2.2.100 DMZHost
    name 10.7.7.100 TestIP description A test IP
    !
    same-security-traffic permit inter-interface
    same-security-traffic permit intra-interface
    object-group network LAN-Hosts
     network-object host LANHost
    object-group network Test-Hosts
     network-object host DMZHost
     network-object host TestIP
    access-list OUTSIDE_access_in extended permit icmp any any
    access-list DMZ_access_in extended permit icmp any any
    access-list DMZ_access_in remark Allow access to FTP
    access-list DMZ_access_in extended permit tcp any host LANHost eq ftp
    access-list DMZ_access_in remark Allow access to SSH
    access-list DMZ_access_in extended permit tcp any host LANHost eq ssh
    access-list DMZ_access_in extended deny ip any 10.1.1.0 255.255.255.0
    access-list DMZ_access_in extended permit ip any any
    access-list RFC1918 standard permit 192.168.0.0 255.255.0.0
    access-list RFC1918 standard permit 172.16.0.0 255.240.0.0
    access-list RFC1918 standard permit 10.0.0.0 255.0.0.0
    logging enable
    logging asdm notifications
    no failover
    username admin password XXXXXXXXXXXXXXXX encrypted privilege 15
    username testuser password YYYYYYYYYYYYYYYY encrypted privilege 3
    !
    class-map inspection_default
     match default-inspection-traffic
    class-map inspection_msrpc
     match port tcp eq 135
    !
    !
    policy-map type inspect dcerpc msrpc_map
     parameters
      timeout pinhole 0:10:00
    policy-map global_policy
     class inspection_msrpc
      inspect dcerpc msrpc_map
     class inspection_default
      inspect ftp
      inspect rsh
      inspect skinny
      inspect sqlnet
      inspect sip
      inspect icmp
      inspect dns
    !
    service-policy global_policy global
    prompt hostname context
    Cryptochecksum:00000000000000000000000000000000
    : end
    ).gsub(/^    /, '').lstrip
    @rc = ASAConsole::Config.new(nested_config: @fake_config)
  end

  context '#line' do
    it 'returns nil on a top-level node' do
      expect(@rc.line).to be_nil
    end
    it 'returns the text matching a selection' do
      expect(@rc.select('failover').line).to eq 'no failover'
      expect(@rc.select('logging', 'asdm').line).to eq 'logging asdm notifications'
    end
    it 'does not modify the key string' do
      config = @rc.select('logging', 'asdm')
      expect(config.keystr).to eq 'logging'
      config.line
      expect(config.keystr).to eq 'logging'
    end
  end

  context '#empty?' do
    it 'returns true when there is no nested config' do
      expect(@rc.select('hostname').empty?).to be true
    end
    it 'returns false when there is nested config' do
      expect(@rc.select('object-group network', 'Test-Hosts').empty?).to be false
    end
  end

  context '#select' do
    it 'can fetch a simple value' do
      entry = @rc.select('terminal width')
      expect(entry.keystr).to eq 'terminal width'
      expect(entry.config_data).to eq '511'
    end
    it 'can fetch a record by name where multiple records of that type exist' do
      entry = @rc.select('name', '10.2.2.100')
      expect(entry.config_name).to eq '10.2.2.100'
      expect(entry.config_data).to eq 'DMZHost'
    end
    it 'can fetch a configuration directive that has been negated' do
      entry = @rc.select('failover')
      expect(entry.config_data).to be_nil
      expect(entry.negated?).to be true
    end
    it 'can tell when a configuration directive has not been negated' do
      entry = @rc.select('logging enable')
      expect(entry.config_data).to be_nil
      expect(entry.negated?).to be false
    end
    it 'can fetch multiple records of a given type' do
      records = []
      @rc.select('same-security-traffic permit') do |entry|
        records << entry.config_data
      end
      expect(records.length).to eq 2
      expect(records.include? 'inter-interface').to be true
      expect(records.include? 'intra-interface').to be true
    end
    it 'can fetch a nested configuration directive' do
      entry = @rc.select('class-map', 'inspection_msrpc').select('match port')
      expect(entry.config_data).to eq 'tcp eq 135'
    end
    it 'can fetch multiple nested records' do
      records = []
      @rc.select('policy-map', 'global_policy')
        .select('class', 'inspection_default')
        .select('inspect') do |entry|
        records << entry.config_data
      end
      expect(records.length).to eq 7
      expect(records.include? 'ftp').to be true
      expect(records.include? 'skinny').to be true
      expect(records.include? 'dns').to be true
    end
  end

  context '#select_all' do
    before :example do
      @object_group = @rc.select('object-group network', 'Test-Hosts')
    end
    it 'returns an array when no block is given' do
      result = @object_group.select_all
      expect(result).to be_an Array
      result.each do |config|
        expect(config).to be_a ASAConsole::Config
      end
    end
    it 'yields and returns nil when a block is given' do
      yielded = false
      result = @object_group.select_all do |config|
        yielded = true
        expect(config).to be_a ASAConsole::Config
      end
      expect(yielded).to be true
      expect(result).to be_nil
    end
  end

  context '#names_of' do
    it 'returns an array of names when a match is found' do
      expect(@rc.names_of('username')).to eq %w( admin testuser )
    end
    it 'returns an empty array when no match is found' do
      expect(@rc.names_of('user')).to eq []
    end
    it 'returns a unique list of names when multiple records with the same name exist' do
      names = @rc.names_of('access-list')
      expect(names.length).to eq 3
      expect(names[0]).to eq 'OUTSIDE_access_in'
      expect(names[1]).to eq 'DMZ_access_in'
      expect(names[2]).to eq 'RFC1918'
    end
    it 'can return nested names' do
      names = @rc.select('object-group network', 'Test-Hosts').names_of('network-object host')
      expect(names).to eq %w( DMZHost TestIP )
    end
  end

end
