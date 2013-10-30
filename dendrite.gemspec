# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'dendrite/version'

Gem::Specification.new do |s|
  s.name        = 'dendrite'
  s.version     = Dendrite::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Brian Akins']
  s.email       = ['brian.akins@turner.com']
  s.homepage    = ''
  s.summary     = ''
  s.description = ''

  s.files        = Dir.glob('{bin,lib}/**/*') + %w()
  s.executables  = ['dendrite']
  s.require_path = 'lib'

  s.add_dependency('chef', "~> 11.6.2")
  s.add_dependency('zk', "~> 1.9.2")
end
