$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "pure_parquet"
require "minitest/autorun"

def fixture(name)
  File.expand_path("fixtures/#{name}", __dir__)
end
