module PureParquet
  # Value and level decoding for a single page.
  class Decoder
    def initialize(data, pos = 0)
      @data = data
      @pos = pos
    end

    attr_reader :pos

    def plain(type, count, type_length = nil)
      case type
      when :boolean then bits(1, count).map { |b| b == 1 }
      when :int32 then take(4 * count).unpack("l<*")
      when :int64 then take(8 * count).unpack("q<*")
      when :float then take(4 * count).unpack("e*")
      when :double then take(8 * count).unpack("E*")
      when :int96 then Array.new(count) { int96_to_nanos(take(12)) }
      when :byte_array then Array.new(count) { take(take(4).unpack1("V")) }
      when :fixed_len_byte_array then Array.new(count) { take(type_length) }
      else raise Error, "unsupported type #{type}"
      end
    end

    # RLE / bit-packing hybrid, as used for levels and dictionary indices.
    # FIXME: no bounds check, a corrupt page can read past its end
    def rle(bit_width, count)
      values = []
      while values.size < count && @pos < @data.bytesize
        header = varint
        if header.odd?
          values.concat(bits(bit_width, (header >> 1) * 8))
        else
          value = take((bit_width + 7) / 8).ljust(4, "\0").unpack1("V")
          values.concat([value] * (header >> 1))
        end
      end
      values.first(count)
    end

    def dictionary_indices(count)
      rle(take(1).ord, count)
    end

    def length_prefixed_rle(bit_width, count)
      length = take(4).unpack1("V")
      Decoder.new(take(length)).rle(bit_width, count)
    end

    private

    def take(n)
      s = @data.byteslice(@pos, n)
      @pos += n
      s
    end

    def bits(width, count)
      return [0] * count if width.zero?

      raw = take((width * count + 7) / 8).unpack1("b*")
      Array.new(count) { |i| raw[i * width, width].reverse.to_i(2) }
    end

    def varint
      value, @pos = Varint.read(@data, @pos)
      value
    end

    JULIAN_DAY_OF_EPOCH = 2_440_588

    def int96_to_nanos(bytes)
      nanos, day = bytes.unpack("Q<l<")
      (day - JULIAN_DAY_OF_EPOCH) * 86_400_000_000_000 + nanos
    end
  end
end
