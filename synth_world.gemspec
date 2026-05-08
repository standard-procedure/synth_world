# frozen_string_literal: true

require_relative "lib/synth_world/version"

Gem::Specification.new do |spec|
  spec.name = "synth_world"
  spec.version = SynthWorld::VERSION
  spec.authors = ["Rahoul Baruah"]
  spec.email = ["rahoulb@echodek.co"]

  spec.summary = "Harness for long-running synthetics"
  spec.description = "I prefer the term 'artificial person'"
  spec.homepage = "https://github.com/standard-procedure/synth_world"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/standard-procedure/synth_world"
  spec.metadata["changelog_uri"] = "https://github.com/standard-procedure/synth_world/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .standard.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby_llm", "~> 1.0"
  spec.add_dependency "dotenv", "~> 3.0"
  spec.add_dependency "async", "~> 2.3"
  spec.add_dependency "literal", "~> 1.9"
  spec.add_dependency "falcon", "~> 0.5"
  spec.add_dependency "async-container"
  spec.add_dependency "sinatra"
  spec.add_dependency "rackup"
  spec.add_dependency "thor"
end
