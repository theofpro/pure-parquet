require_relative "test_helper"

class ReaderTest < Minitest::Test
  def test_plain
    reader = PureParquet.read(fixture("alltypes_plain.parquet"))
    assert_equal 8, reader.num_rows
    assert_equal [4, 5, 6, 7, 2, 3, 0, 1], reader.read_column("id")
    assert_equal [true, false] * 4, reader.read_column("bool_col")
    assert_equal [0, 10] * 4, reader.read_column("bigint_col")
    assert_equal [0.0, 10.1] * 4, reader.read_column("double_col")
  end

  def test_strings_and_binary
    reader = PureParquet.read(fixture("alltypes_plain.parquet"))
    assert_equal %w[0 1] * 4, reader.read_column("string_col")
    assert_equal "03/01/09".b, reader.read_column("date_string_col").first
  end

  def test_int96_timestamps
    reader = PureParquet.read(fixture("alltypes_plain.parquet"))
    assert_equal Time.utc(2009, 3, 1), Time.at(0, reader.read_column("timestamp_col").first, :nanosecond).utc
  end

  def test_snappy
    reader = PureParquet.read(fixture("alltypes_plain.snappy.parquet"))
    assert_equal [6, 7], reader.read_column("id")
    assert_equal [0.0, 10.1], reader.read_column("double_col")
  end

  def test_dictionary
    reader = PureParquet.read(fixture("alltypes_dictionary.parquet"))
    assert_equal [0, 1], reader.read_column("id")
    assert_equal %w[0 1], reader.read_column("string_col")
  end

  def test_nulls_in_nested_struct
    reader = PureParquet.read(fixture("nulls.snappy.parquet"))
    assert_equal ["b_struct.b_c_int"], reader.column_names
    assert_equal [nil] * 8, reader.read_column("b_struct.b_c_int")
  end

  def test_each_row
    rows = PureParquet.read(fixture("alltypes_dictionary.parquet")).each_row.to_a
    assert_equal 2, rows.size
    assert_equal({ "id" => 1, "string_col" => "1" }, rows[1].slice("id", "string_col"))
  end

  def test_not_parquet
    assert_raises(PureParquet::Error) { PureParquet.read(__FILE__) }
  end
end
