module PureParquet
  module Snappy
    module_function

    def decompress(src)
      length, pos = Varint.read(src, 0)
      out = String.new(capacity: length, encoding: Encoding::BINARY)

      while pos < src.bytesize
        tag = src.getbyte(pos)
        pos += 1

        if tag & 3 == 0
          len = tag >> 2
          if len >= 60
            n = len - 59
            len = src.byteslice(pos, n).ljust(4, "\0").unpack1("V")
            pos += n
          end
          len += 1
          out << src.byteslice(pos, len)
          pos += len
          next
        end

        case tag & 3
        when 1
          len = ((tag >> 2) & 7) + 4
          offset = ((tag >> 5) << 8) | src.getbyte(pos)
          pos += 1
        when 2
          len = (tag >> 2) + 1
          offset = src.byteslice(pos, 2).unpack1("v")
          pos += 2
        else
          len = (tag >> 2) + 1
          offset = src.byteslice(pos, 4).unpack1("V")
          pos += 4
        end
        copy(out, offset, len)
      end

      raise Error, "snappy: bad length" unless out.bytesize == length

      out
    end

    def copy(out, offset, len)
      start = out.bytesize - offset
      if offset >= len
        out << out.byteslice(start, len)
      else
        len.times { |i| out << out.getbyte(start + i) }
      end
    end
  end
end
