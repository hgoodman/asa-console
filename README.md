[![Build Status](https://travis-ci.org/hgoodman/asa-console.svg?branch=master)](https://travis-ci.org/hgoodman/asa-console)
[![Code Climate](https://codeclimate.com/github/hgoodman/asa-console/badges/gpa.svg)](https://codeclimate.com/github/hgoodman/asa-console)
[![Test Coverage](https://codeclimate.com/github/hgoodman/asa-console/badges/coverage.svg)](https://codeclimate.com/github/hgoodman/asa-console/coverage)
[![Gem Version](https://badge.fury.io/rb/asa_console.svg)](https://badge.fury.io/rb/asa_console)
[![YARD Docs](https://img.shields.io/badge/yard-docs-blue.svg)](http://www.rubydoc.info/github/hgoodman/asa-console/)

ASAConsole
==========

A ruby gem for Cisco ASA management via an interactive terminal session.

This gem lets a program interact with a Cisco ASA using CLI commands. It includes a minimal set of functions for issuing commands and parsing the results.

Caveats
=======

This gem provides an alternative to installing [Cisco's official REST API](http://www.cisco.com/c/en/us/td/docs/security/asa/api/qsg-asa-api.html) plugin for the ASA platform. You may find it particularly useful if you are working with older hardware or software versions. The official REST API plugin is only supported on 5500-X, ASAv and newer platforms.

For the time being, direct SSH is the only transport method implemented by this gem although it could easily be extended to support alternatives like using a serial console or a jump box.

Getting Started
===============

The easiest way to get started is to browse through the test files in the [script](script/) folder. To supplement its automated tests, this gem provides a framework for live testing against devices in a lab environment. There are several canned test scripts that demonstrate different features of the library.

Each script executes a series of commands declared in a block as show below. The test runner displays output as it would appear in an SSH session and adds color to indicate how the output is being parsed. Informational messages can be added to the output with the `log` method.

~~~ ruby
ASAConsole::Test.script do |asa|
  log 'Connecting...'
  asa.connect
  if asa.version? '>= 9.4(1)'
    asa.priv_exec 'no terminal interactive'
  else
    log 'The "no terminal interactive" command is not supported'
  end
  log 'Disconnecting...'
  asa.disconnect
end
~~~

The included test scripts are designed to be non-invasive and to leave the device configuration in its original state. Nevertheless, running them in a production environment is not recommended.

Command Line Utility
--------------------

**Usage**

    asatest [options] <testname> [asaname]

**Examples**

List command line options and available tests:

    asatest --help

Execute a canned test:

    asatest connect

Load a custom test file:

    asatest -f ./my_test_file.rb

Configuration Files
-------------------

The `asatest` executable will read a list of default command line options from the file `~/.asa-console/test_options.yaml`. Here is an example of the file format:

~~~ yaml
---
show-session-log: true
color: light
~~~

Each key matches a long-form command line option with the leading "--" removed. Run the program with "--help" for a complete list.

Device information is needed for running live tests. By default, the program will look for appliance information in `~/.asa-console/test_appliances.yaml`. Here is an example of the file format:

~~~ yaml
---
default_appliance: firewall002
appliances:
  firewall001:
    terminal_opts:
      host: 10.7.7.1
      connect_timeout: 20
  firewall002:
    terminal_opts:
      host: 10.7.7.254
      user: testuser
      password: execpass
    enable_password: enablepass
~~~

If any of the following options are not found in this file, the user will be prompted to enter values for them.

- `terminal_opts[host]`
- `terminal_opts[user]`
- `terminal_opts[password]`
- `enable_password`

The enable password can be omitted if it is the same as the terminal password or if it is otherwise not needed.

API Documentation
=================

You can view online documentation at [rubydoc.info](http://www.rubydoc.info/github/hgoodman/asa-console/) or generate it yourself with:

    rake yardoc

To include documentation for objects used in testing and development:

    rake yardoc_dev
