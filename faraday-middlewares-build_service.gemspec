# frozen_string_literal: true

require_relative "lib/faraday/middlewares/build_service/version"

Gem::Specification.new do |spec|
  spec.name = "faraday-middlewares-build_service"
  spec.version = Faraday::Middlewares::BuildService::VERSION
  spec.authors = ["Jose D. Gomez R."]
  spec.email = ["jose.gomez@suse.com"]

  spec.summary = "Plug-and-play authentication for requests against Build Service"
  spec.description = <<~DESC
    Faraday middleware to automatically negotiate authentication with Build Service instances.

    It can handle: No, Basic, and, Signature authentication.
  DESC
  spec.homepage = "https://github.com/SUSE/faraday-middlewares-bs-auth"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 1.10"
  spec.add_dependency "http-cookie", "~> 1.0"
end
