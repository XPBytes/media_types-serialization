
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'media_types/serialization/version'

Gem::Specification.new do |spec|
  spec.name          = 'media_types-serialization'
  spec.version       = MediaTypes::Serialization::VERSION
  spec.authors       = ['Derk-Jan Karrenbeld', 'Max Maton']
  spec.email         = ['derk-jan@xpbytes.com', 'max@delftsolutions.nl']

  spec.summary       = 'Add media types supported serialization using your favourite serializer'
  spec.homepage      = 'https://github.com/XPBytes/media_types-serialization'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    # spec.metadata['allowed_push_host'] = 'TODO: Set to 'http://mygemserver.com''

    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = spec.homepage
    spec.metadata['changelog_uri'] = spec.homepage + '/blob/master/CHANGELOG.md'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'actionpack', '>= 6.0.0'
  spec.add_dependency 'activesupport', '>= 6.0.0'
  spec.add_dependency 'media_types', '>= 2.2.3', '< 3.0.0'

  spec.add_development_dependency 'awesome_print'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rails', '~> 6.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'oj'
end
