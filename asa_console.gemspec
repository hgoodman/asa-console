
Gem::Specification.new do |s|
  s.name        = 'asa_console'
  s.version     = '0.1.2'
  s.summary     = 'Cisco ASA management via an interactive terminal session'
  s.description = 'This gem lets a program interact with a Cisco ASA using CLI
  commands. It includes a minimal set of functions for issuing commands and
  parsing the results.'.gsub(/\s+/, ' ')
  s.author      = 'Henry Goodman'
  s.email       = 'github@henrygoodman.com'
  s.homepage    = 'https://github.com/hgoodman/asa-console/'
  s.license     = 'MIT'
  s.has_rdoc    = 'yard'
  s.files       = Dir[__FILE__, 'lib/**/*', 'script/*', '*.md', '.yardopts']
  s.executables = ['asatest']

  s.add_runtime_dependency('net-ssh', '~> 2.9.2')
  s.add_runtime_dependency('highline', '~> 1.7')

  s.add_development_dependency('bundler',   '~> 1.7')
  s.add_development_dependency('kramdown',  '~> 1.9')
  s.add_development_dependency('rake',      '~> 10.4')
  s.add_development_dependency('rspec',     '~> 3.4')
  s.add_development_dependency('rubocop',   '~> 0.35')
  s.add_development_dependency('simplecov', '~> 0.11')
  s.add_development_dependency('thor',      '~> 0.19')
  s.add_development_dependency('yard',      '~> 0.8')

  s.required_ruby_version = '>=1.9.3'
end
