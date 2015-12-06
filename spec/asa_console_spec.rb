
require 'spec_helper'
require 'asa_console'

RSpec.describe ASAConsole do

  context 'with an ssh terminal initialized with an unreachable host' do
    before :example do
      @asa = ASAConsole.ssh(
        host: '192.0.2.1', # Non-routable IP from RFC 5737
        user: 'testuser',
        password: 'testpass',
        connect_timeout: 1
      )
    end
    it 'is initially disconnected' do
      expect(@asa.connected?).to be false
    end
    it 'correctly sets the connection timeout' do
      expect(@asa.terminal.connect_timeout).to eq 1
      @asa.terminal.connect_timeout = 0.1
      expect(@asa.terminal.ssh_opts[:timeout]).to eq 0.1
    end
    it 'raises Error::ConnectFailure when attempting to connect' do
      expect { @asa.connect }.to raise_error ASAConsole::Error::ConnectFailure
    end
  end

  context 'with a fake ssh terminal' do
    before :example do
      input_proc = proc do |input, prompt|
        disconnect = false
        if input.nil?
          prompt = 'TEST> '
          output = "Type help or '?' for a list of available commands.\n" + prompt
        else
          case input.chomp
          when 'enable'
            output = prompt = 'Password: '
          when 'terminal pager lines 0'
            output = prompt
          when 'show version'
            output = "Cisco Adaptive Security Appliance Software Version 7.3(0)\n" + prompt
          when 'configure terminal'
            output = prompt = 'TEST(config)# '
          when 'terminal width 0'
            output = prompt
          when 'show running-config terminal'
            output = "terminal width 511\n" + prompt
          when 'show running-config object id NONEXISTENT'
            output = "ERROR: object (NONEXISTENT) does not exist.\n" + prompt
          when 'interface Management0/0'
            output = prompt = 'TEST(config-if)# '
          when 'pod-bay-doors open'
            output = "I'm sorry, Dave. I'm afraid I can't do that.\n" + prompt
          when 'show running-config dhcpd'
            output = prompt
          when 'exit'
            if prompt == 'TEST(config-if)# '
              output = prompt = 'TEST(config)# '
            elsif prompt == 'TEST(config)# '
              output = prompt = 'TEST# '
            else
              output = "\nLogoff\n\n"
              disconnect = true
            end
          else
            if prompt == 'Password: '
              output = prompt = 'TEST# '
            else
              output = "ERROR: Command not implemented in fake terminal\n" + prompt
            end
          end
        end
        [ output, prompt, disconnect ]
      end
      @asa = ASAConsole.fake_ssh(
        host: 'test.example.com',
        user: 'testuser',
        password: 'testpass',
        input_proc: input_proc
      )
      @asa.connect
    end

    it 'starts in privileged EXEC mode' do
      expect(@asa.connected?).to be true
      expect(@asa.terminal.prompt).to match ASAConsole::PRIV_EXEC_PROMPT
    end
    it 'keeps a session log' do
      expect(@asa.terminal.session_log.empty?).to be false
    end
    it 'can disconnect' do
      @asa.disconnect
      expect(@asa.connected?).to be false
    end
    it 'can check the software version' do
      expect(@asa.version).to eq '7.3(0)'
      expect(@asa.version? '7.x').to be true
      expect(@asa.version? '!7.x').to be false
      success = false
      @asa.version? '>= 7.3', '< 8' do
        success = true
      end
      expect(success).to be true
    end
    it 'raises Error::CommandError when executing an invalid command' do
      expect { @asa.priv_exec! 'derp derp derp' }.to raise_error ASAConsole::Error::CommandError
      expect { @asa.config_exec! 'derp derp derp' }.to raise_error ASAConsole::Error::CommandError
    end
    it 'raises Error::UnexpectedOutputError when a configuration command generates unexpected output' do
      expect { @asa.config_exec! 'pod-bay-doors open' }.to \
        raise_error ASAConsole::Error::UnexpectedOutputError
    end
    it 'returns an empty Config object when "show running-config" produces an error' do
      expect(@asa.running_config('object id NONEXISTENT').empty?).to be true
    end

    context 'after executing a configuration command' do
      before :example do
        @asa.config_exec 'terminal width 0'
      end
      it 'enters configuration mode' do
        expect(@asa.config_mode).to_not be_nil
      end
      it 'can inspect the running config' do
        expect(@asa.running_config('terminal').select('terminal width').config_data).to eq '511'
      end
      it 'can exit the configuration mode with #priv_exec!' do
        @asa.priv_exec! 'show version'
        expect(@asa.config_mode).to be_nil
      end
      it 'raises Error::ConfigModeError when not in the required configuration submode' do
        expect do
          @asa.config_exec 'security-level 100', require_config_mode: 'config-if'
        end.to raise_error ASAConsole::Error::ConfigModeError
      end
    end

    context 'after executing an interface configuration command' do
      before :example do
        @asa.config_exec 'interface Management0/0'
      end
      it 'enters interface configuration submode' do
        expect(@asa.config_mode).to eq 'config-if'
      end
      it 'can exit interface configuration submode with #config_exec!' do
        @asa.config_exec! 'terminal width 0'
        expect(@asa.config_mode).to eq 'config'
      end
    end
  end

end
