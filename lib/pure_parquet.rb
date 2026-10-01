require "stringio"

require_relative "pure_parquet/version"

module PureParquet
  class Error < StandardError; end

  MAGIC = "PAR1".b.freeze
end
