require_relative "lib/pure_parquet/version"

Gem::Specification.new do |spec|
  spec.name = "pure-parquet"
  spec.version = PureParquet::VERSION
  spec.authors = ["Théo Fleury"]
  spec.summary = "Apache Parquet reader written in pure Ruby"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.1"
  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
end
