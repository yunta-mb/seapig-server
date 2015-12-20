$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "seapig/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "seapig-server"
  s.version     = Seapig::VERSION
  s.authors     = ["yunta"]
  s.email       = ["maciej.blomberg@mikoton.com"]
  s.homepage    = "http://meh.no"
  s.summary     = "Transient object synchronization lib"
  s.description = "meh"
  s.license     = "MIT"

  s.files = Dir["{lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc", "bin/seapig-*"]
  s.test_files = Dir["test/**/*"]
  s.executables = ["seapig-server"]
  s.require_paths = ["lib"]

  s.add_dependency "websocket-eventmachine-server"
  s.add_dependency "jsondiff"
  s.add_dependency "hana"

end
