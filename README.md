# pure-parquet

A Parquet reader in plain Ruby, no native extension.

```ruby
require "pure_parquet"

reader = PureParquet.read("data.parquet")
reader.column_names
reader.read_column("id")
reader.each_row { |row| p row }
```

It reads flat and optional columns with PLAIN or dictionary encoding, data pages
v1 and v2, uncompressed, Snappy or Gzip. Lists, maps, DELTA encodings, ZSTD and
writing are not there yet.

Tests run on files from apache/parquet-testing: `bundle exec rake`

Apache-2.0
