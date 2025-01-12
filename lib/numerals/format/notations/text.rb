module Numerals

  class Format

    class TextNotation < Notation

      def assemble(output, text_parts)
        if text_parts.special?
          output << text_parts.special
        else
          if format.symbols.padding.padded?
            output_size = OutputSize.new
            assemble_parts(output_size, text_parts)
            left_padding, internal_padding, right_padding = format.symbols.paddings(output_size.size)
          end
          assemble_parts(output, text_parts, left_padding, internal_padding, right_padding)
        end
      end

      def disassemble(text)
        text_parts = TextParts.new
        s = format.symbols
        special = /
          \A
          #{s.regexp(:plus, :minus, case_sensitivity: true)}?
          \s*
          #{s.regexp(:nan, :infinity, case_sensitivity: true)}
          \Z
        /x
        if match = special.match(text)
          valid = true
          text_parts.special = "#{match[1]}#{match[2]}"
        else
          valid = true
          base = format.significand_base
          # TODO: replace numbered groups by named variables ?<var>
          regular = /
            \A
            #{s.regexp(:fill, no_capture: true, optional: true, multiple: true)}
            #{s.regexp(:plus, :minus)}?
            \s*
            #{s.regexp(:fill, no_capture: true, optional: true, multiple: true)}
            #{s.regexp(:base_prefix, no_capture: true, optional: true)}
            (?:
              (?:(#{s.regexp(:grouped_digits, base: base, no_capture: true)}+)#{s.regexp(:point)}?)
              |
              #{s.regexp(:point)} # admit empty integer part, but then a point is needed
            )
            (#{s.regexp(:digits, base: base, no_capture: true)}*)
            (?:#{s.regexp(:repeat_begin)}(#{s.regexp(:digits, base: base, no_capture: true)}+)#{s.regexp(:repeat_end)})?
            #{s.regexp(:repeat_suffix)}?
            #{s.regexp(:base_suffix, no_capture: true, optional: true)}
            (?:#{s.regexp(:exponent)}#{s.regexp(:plus, :minus)}?(\d+))?
            #{s.regexp(:fill, no_capture: true, optional: true, multiple: true)}
            \Z
          /x
          unless s.case_sensitive?
            regular = Regexp.new(regular.source, regular.options | Regexp::IGNORECASE)
          end

          match = regular.match(text)

          if match.nil?
            valid = false
          else
            # TODO: we could avoid capturing point, point_with_no_integer_part
            sign = match[1]
            integer_part = match[2]
            _point = match[3]
            _point_with_no_integer_part = match[4]
            fractional_part = match[5]
            repeat_begin = match[6]
            repeat_part = match[7]
            repeat_end = match[8]
            repeat_suffix = match[9]
            exponent = match[10]
            exponent_sign = match[11]
            exponent_value = match[12]

            text_parts.sign = sign
            text_parts.integer = integer_part
            text_parts.fractional = fractional_part

            if repeat_begin
              if !repeat_part || !repeat_end || repeat_suffix
                valid = false
              end
              text_parts.repeat = repeat_part
            else
              if repeat_part || repeat_end
                valid = false
              end
              if repeat_suffix
                text_parts.detect_repeat = true
              end
            end

            text_parts.exponent_base = format.base
            if exponent
              if !exponent_value
                valid = false
              end
              text_parts.exponent = "#{exponent_sign}#{exponent_value}"
              text_parts.exponent_value = text_parts.exponent.to_i
            else
              if exponent_sign || exponent_value
                valid = false
              end
            end
          end
        end
        raise "Invalid text numeral" unless valid
        text_parts
      end

      private

      class OutputSize
        def initialize
          @size = 0
        end
        def <<(text)
          @size += text.size
        end
        attr_reader :size
      end

      def assemble_parts(output, text_parts, left_padding='', internal_padding='', right_padding='')
        output << left_padding
        output << text_parts.sign
        if format.symbols.base_prefix
          output << format.symbols.base_prefix
        end
        output << internal_padding
        output << text_parts.integer # or decide here if empty integer part is show as 0?
        if text_parts.show_point?(format)
          output << format.symbols.point
        end
        output << text_parts.fractional
        if text_parts.repeat?
          if format.symbols.repeat_delimited
            output << format.symbols.repeat_begin
            output << text_parts.repeat
            output << format.symbols.repeat_end
          else
            n = RepeatDetector.min_repeat_count(
                  text_parts.numeral.digits.digits_array,
                  text_parts.numeral.repeat,
                  format.symbols.repeat_count - 1
                )
            n.times do
              output << text_parts.repeat
            end
            output << format.symbols.repeat_suffix
          end
        end
        if format.symbols.base_suffix
          output << format.symbols.base_suffix
        end
        if text_parts.exponent_value != 0 || format.mode.mode == :scientific
          output << format.symbols.exponent
          output << text_parts.exponent
        end
        output << right_padding
      end

    end

    define_notation :text, TextNotation

  end

end
