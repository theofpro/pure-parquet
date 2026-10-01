require "stringio"

require_relative "pure_parquet/version"
require_relative "pure_parquet/varint"
require_relative "pure_parquet/thrift"
require_relative "pure_parquet/snappy"
require_relative "pure_parquet/decoder"

module PureParquet
  class Error < StandardError; end

  MAGIC = "PAR1".b.freeze
end
