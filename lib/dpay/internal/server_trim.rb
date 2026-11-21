# frozen_string_literal: true

module DPay
  module Internal
    # The trimming the panel API applies to every request string before it verifies the checksum (Laravel 13 global
    # TrimStrings middleware, Illuminate\Support\Str::trim()). A signed string with any of these characters at either
    # end would be hashed by the API without them and answered 401 "Unauthorized request", so the SDK sends and signs
    # the trimmed value. Characters inside the string are kept. String#strip is not the same (ASCII whitespace and
    # NUL only).
    module ServerTrim
      # Code points removed from both ends: \s of PCRE2 in UTF/UCP mode (tab, LF, VT, FF, CR, space, NEL, the Z
      # category), NUL and Laravel's Str::INVISIBLE_CHARACTERS.
      CODE_POINTS = [
        0x0000, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x0020, 0x0085, 0x00A0, 0x00AD, 0x034F, 0x061C, 0x115F,
        0x1160, 0x1680, 0x17B4, 0x17B5, 0x180E, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007,
        0x2008, 0x2009, 0x200A, 0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x2028, 0x2029, 0x202F, 0x205F, 0x2060,
        0x2061, 0x2062, 0x2063, 0x2064, 0x2065, 0x206A, 0x206B, 0x206C, 0x206D, 0x206E, 0x206F, 0x2800, 0x3000,
        0x3164, 0xFEFF, 0xFFA0, 0x1D159, 0x1D173, 0x1D174, 0x1D175, 0x1D176, 0x1D177, 0x1D178, 0x1D179, 0x1D17A,
        0xE0020
      ].freeze
      LOOKUP = CODE_POINTS.to_h { |code_point| [code_point, true] }.freeze
      # Encodings whose bytes the JSON encoder takes as UTF-8 as they are.
      UTF8_BYTES = [Encoding::UTF_8, Encoding::US_ASCII, Encoding::BINARY].freeze

      module_function

      # Trims by code point. A string that is not valid UTF-8 (it cannot be sent as JSON anyway) is returned
      # unchanged, as is a string with nothing to trim; a trimmed string is UTF-8.
      def trim(value)
        code_points = utf8_code_points(value)
        return value if code_points.nil?

        first = 0
        last = code_points.length
        first += 1 while first < last && LOOKUP.key?(code_points.fetch(first))
        last -= 1 while last > first && LOOKUP.key?(code_points.fetch(last - 1))
        return value if first.zero? && last == code_points.length

        (code_points[first...last] || []).pack("U*")
      end

      # Trims every string of a Hash or an Array, nested ones included (keys and order are kept); other values are
      # returned as they are.
      def trim_strings(value)
        case value
        when String then trim(value)
        when Hash then value.transform_values { |item| trim_strings(item) }
        when Array then value.map { |item| trim_strings(item) }
        else value
        end
      end

      # The trimmed value of a required String field; raises when nothing is left (the API would answer 422).
      def required(value, field)
        raise InvalidArgumentError, "#{field} must be a string" unless value.is_a?(String)

        trimmed = trim(value)
        raise InvalidArgumentError, "#{field} must not be empty" if trimmed.empty?

        trimmed
      end

      def utf8_code_points(value)
        utf8 = UTF8_BYTES.include?(value.encoding) ? value.dup.force_encoding(Encoding::UTF_8) : value.encode(Encoding::UTF_8)
        utf8.valid_encoding? ? utf8.codepoints : nil
      rescue EncodingError
        nil
      end
    end
  end
end
