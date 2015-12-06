
Gem::Specification.new do |s|
  s.name        = 'asa_console'
  s.version     = '0.0.0'
  s.summary     = 'Cisco ASA management via an interactive terminal session'
  s.description = 'This gem lets a program interact with a Cisco ASA using CLI
  commands. It includes a minimal set of functions for issuing commands and
  parsing the results.'.gsub(/\s+/, ' ')
  s.author      = 'Henry Goodman'
  s.email       = 'github@henrygoodman.com'
  s.homepage    = 'https://github.com/hgoodman/asa-console/'
  s.license     = 'MIT'
  s.files       = Dir[__FILE__, 'lib/**/*', 'script/*']
  s.executables = ['asatest']

  s.add_runtime_dependency('net-ssh', '~> 2.9.2')
  s.add_runtime_dependency('highline', '~> 1.7')

  s.add_development_dependency('bundler',   '~> 1.3')
  s.add_development_dependency('rake',      '~> 10.4')
  s.add_development_dependency('redcarpet', '~> 3.3')
  s.add_development_dependency('rspec',     '~> 3.4')
  s.add_development_dependency('rubocop',   '~> 0.35.1')
  s.add_development_dependency('simplecov', '~> 0.10')
  s.add_development_dependency('yard',      '~> 0.8')

  s.required_ruby_version = '>=1.9.3'
end