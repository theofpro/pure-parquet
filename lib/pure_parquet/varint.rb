module PureParquet
  module Varint
    module_function

    # Unsigned LEB128. Returns [value, next_pos].
    def read(data, pos)
      value = 0
      shift = 0
      loop do
        byte = data.getbyte(pos) or raise Error, "truncated varint"
        pos += 1
        value |= (byte & 0x7f) << shift
        return [value, pos] if byte < 0x80

        shift += 7
      end
    end
  end
end
