require "zlib"

module PureParquet
  class Reader
    TYPES = %i[boolean int32 int64 int96 float double byte_array fixed_len_byte_array].freeze

    Column = Struct.new(:name, :path, :type, :type_length, :max_definition_level, :string)

    attr_reader :num_rows, :columns

    def initialize(path)
      @data = File.binread(path)
      unless @data.start_with?(MAGIC) && @data.end_with?(MAGIC)
        raise Error, "#{path} is not a parquet file"
      end

      footer_length = @data.byteslice(-8, 4).unpack1("V")
      @metadata = ThriftReader.new(@data, @data.bytesize - 8 - footer_length).read_struct
      @num_rows = @metadata[3]
      @columns = []
      parse_schema(@metadata[2])
    end

    def column_names
      @columns.map(&:name)
    end

    def read_column(name)
      index = column_names.index(name) or raise ArgumentError, "unknown column #{name}"
      column = @columns[index]
      @metadata[4].flat_map { |row_group| read_chunk(column, row_group[1][index][3]) }
    end

    def to_h
      column_names.to_h { |name| [name, read_column(name)] }
    end

    def each_row
      return enum_for(:each_row) unless block_given?

      table = to_h
      @num_rows.times do |i|
        yield table.transform_values { |values| values[i] }
      end
    end

    private

    # Walks the flattened schema tree and keeps the leaves.
    def parse_schema(elements)
      index = 1
      walk = lambda do |path, definition_level|
        element = elements[index]
        index += 1
        repetition = element[3] || 0
        # TODO: repetition levels, needed for lists and maps
        raise Error, "repeated fields are not supported yet" if repetition == 2

        level = definition_level + (repetition == 1 ? 1 : 0)
        children = element[5] || 0
        if children.zero?
          logical = element[10] || {}
          string = element[6] == 0 || logical.key?(1)
          @columns << Column.new((path + [element[4]]).join("."), path + [element[4]],
                                 TYPES[element[1]], element[2], level, string)
        else
          children.times { walk.call(path + [element[4]], level) }
        end
      end
      (elements[0][5] || 0).times { walk.call([], 0) }
    end

    def read_chunk(column, meta)
      codec = meta[4]
      pos = [meta[11], meta[9]].compact.reject(&:zero?).min
      stop = pos + meta[7]
      dictionary = nil
      values = []

      while pos < stop && values.size < meta[5]
        thrift = ThriftReader.new(@data, pos)
        header = thrift.read_struct
        body = @data.byteslice(thrift.pos, header[3])
        pos = thrift.pos + header[3]

        case header[1]
        when 0 then values.concat(read_data_page(column, header, decompress(codec, body), dictionary))
        when 2
          page = Decoder.new(decompress(codec, body))
          dictionary = convert(column, page.plain(column.type, header[7][1], column.type_length))
        when 3 then values.concat(read_data_page_v2(column, header, body, codec, dictionary))
        end
      end
      values
    end

    def read_data_page(column, header, data, dictionary)
      page = header[5]
      count = page[1]
      decoder = Decoder.new(data)
      levels = column.max_definition_level.zero? ? nil : decoder.length_prefixed_rle(bit_width(column), count)
      present = levels ? levels.count(column.max_definition_level) : count
      fill_nulls(column, levels, decode(column, decoder, page[2], present, dictionary))
    end

    def read_data_page_v2(column, header, body, codec, dictionary)
      page = header[8]
      count = page[1]
      levels_length = page[5] + page[6]
      levels = nil
      if column.max_definition_level.positive?
        levels = Decoder.new(body.byteslice(page[6], page[5])).rle(bit_width(column), count)
      end
      data = body.byteslice(levels_length, body.bytesize - levels_length)
      data = decompress(codec, data) unless page[7] == false
      present = levels ? levels.count(column.max_definition_level) : count
      fill_nulls(column, levels, decode(column, Decoder.new(data), page[4], present, dictionary))
    end

    def decode(column, decoder, encoding, count, dictionary)
      case encoding
      when 0 then convert(column, decoder.plain(column.type, count, column.type_length))
      when 2, 8 then decoder.dictionary_indices(count).map { |i| dictionary[i] }
      else raise Error, "encoding #{encoding} is not supported yet"
      end
    end

    def fill_nulls(column, levels, values)
      return values unless levels

      iterator = values.each
      levels.map { |level| level == column.max_definition_level ? iterator.next : nil }
    end

    def convert(column, values)
      return values unless column.string

      values.map { |v| v.force_encoding(Encoding::UTF_8) }
    end

    def bit_width(column)
      column.max_definition_level.bit_length
    end

    def decompress(codec, data)
      case codec
      when 0 then data
      when 1 then Snappy.decompress(data)
      when 2 then Zlib::GzipReader.new(StringIO.new(data)).read.b
      # TODO: zstd, most recent files use it
      else raise Error, "compression codec #{codec} is not supported yet"
      end
    end
  end
end
