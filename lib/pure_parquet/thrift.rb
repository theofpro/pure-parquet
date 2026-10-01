module PureParquet
  # Thrift compact protocol, read side only.
  # Structs are decoded into hashes keyed by field id.
  class ThriftReader
    STOP, TRUE, FALSE, BYTE, I16, I32, I64, DOUBLE, BINARY, LIST, SET, MAP, STRUCT = (0..12).to_a

    attr_reader :pos

    def initialize(data, pos = 0)
      @data = data
      @pos = pos
    end

    def read_struct
      fields = {}
      last_id = 0
      loop do
        header = read_byte
        type = header & 0x0f
        break if type == STOP

        delta = header >> 4
        id = delta.zero? ? read_zigzag : last_id + delta
        last_id = id
        fields[id] = read_value(type)
      end
      fields
    end

    private

    def read_value(type)
      case type
      when TRUE then true
      when FALSE then false
      when BYTE then read_byte
      when I16, I32, I64 then read_zigzag
      when DOUBLE then read_bytes(8).unpack1("E")
      when BINARY then read_bytes(read_varint)
      when LIST, SET then read_list
      when MAP then read_map
      when STRUCT then read_struct
      else raise Error, "unknown thrift type #{type}"
      end
    end

    def read_list
      header = read_byte
      size = header >> 4
      size = read_varint if size == 15
      type = header & 0x0f
      if type == TRUE || type == FALSE
        Array.new(size) { read_byte == TRUE }
      else
        Array.new(size) { read_value(type) }
      end
    end

    def read_map
      size = read_varint
      return {} if size.zero?

      types = read_byte
      Array.new(size) { [read_value(types >> 4), read_value(types & 0x0f)] }.to_h
    end

    def read_byte
      byte = @data.getbyte(@pos) or raise Error, "unexpected end of thrift data"
      @pos += 1
      byte
    end

    def read_bytes(n)
      s = @data.byteslice(@pos, n)
      @pos += n
      s
    end

    def read_varint
      value, @pos = Varint.read(@data, @pos)
      value
    end

    def read_zigzag
      n = read_varint
      (n >> 1) ^ -(n & 1)
    end
  end
end
