require 'numerals/conversions/context_conversion'

module Numerals

  class FltConversion < ContextConversion

    # Options:
    #
    # * :input_rounding (optional, a non-exact Rounding or rounding mode)
    #   which is used when input is approximate as the assumed rounding
    #   mode which would be used so that the result numeral rounds back
    #   to the input number. :context can be used to use the
    #   numeric context as input rounding.
    #   input_rounding is also used to round input ...
    #
    def initialize(context_or_type, options={})
      super
    end

    def order_of_magnitude(value, options={})
      base = options[:base] || 10 # value.num_class.radix
      if value.class.radix == base
        value.adjusted_exponent + 1
      else
        value.abs.log(base).floor + 1
      end
    end

    def number_of_digits(value, options={})
      base = options[:base] || 10
      if base == @context.radix
        value.number_of_digits
      else
        x.class.context[precision: value.number_of_digits].necessary_digits(base)
      end
    end

    def exact?(value, options={})
      options[:exact]
    end

    # mode is either :exact or :approximate
    def number_to_numeral(number, mode, rounding)
      if number.special? # @context.special?(number)
        special_num_to_numeral(number)
      else
        if mode == :exact
          exact_num_to_numeral number, rounding
        else # mode == :approximate
          approximate_num_to_numeral(number, rounding)
        end
      end
    end

    def numeral_to_number(numeral, mode)
      if numeral.special?
        special_numeral_to_num numeral
      elsif mode == :fixed
        fixed_numeral_to_num numeral
      else # mode == :free
        free_numeral_to_num numeral
      end
    end

    def write(number, exact_input, output_rounding)
      output_base = output_rounding.base
      input_base = @context.radix

      if number.special? # @context.special?(number)
        special_num_to_numeral number
      elsif exact_input
        if output_base == input_base && output_rounding.free?
          # akin to number.format(base: output_base, simplified: true)
          general_num_to_numeral number, output_rounding, false
        else
          # akin to number.format(base: output_base, exact: true)
          exact_num_to_numeral number, output_rounding
        end
      else
        if output_base == input_base && output_rounding.preserving?
          # akin to number.format(base: output_base)
          Numeral.from_coefficient_scale(
            number.sign*number.coefficient, number.integral_exponent,
            approximate: true, base: output_base
          )
        elsif output_rounding.simplifying?
          # akin to number.forma(base: output_base, simplify: true)
          general_num_to_numeral number, output_rounding, false
        else
          # akin to number.forma(base: output_base, all_digits: true)
          general_num_to_numeral number, output_rounding, true
        end
      end
    end

    def read(numeral, exact_input, approximate_simplified)
      if numeral.special?
        special_numeral_to_num numeral
      elsif numeral.approximate? && !exact_input
        if approximate_simplified
          # akin to @context.Num(numeral_text, :short)
          short_numeral_to_num numeral
        else
          # akin to @context.Num(numeral_text, :free)
          free_numeral_to_num numeral
        end
      else
        # akin to @context.Num(numeral_text, :fixed)
        numeral = numeral.exact if exact_input
        fixed_numeral_to_num numeral
      end
    end

    private

    def special_num_to_numeral(x)
      if x.nan?
        Numeral.nan
      elsif x.infinite?
        Numeral.infinity @context.sign(x)
      end
    end

    def exact_num_to_numeral(number, rounding)
      quotient = number.to_r
      numeral = Numerals::Numeral.from_quotient(quotient, base: rounding.base)
      unless rounding.free?
        numeral = rounding.round(numeral)
      end
      numeral
    end

    def approximate_num_to_numeral(number, rounding)
      all_digits = !rounding.free?
      general_num_to_numeral(number, rounding, all_digits)
    end

    def general_num_to_numeral(x, rounding, all_digits)
      sign, coefficient, exponent = x.split # @context.split(x)
      precision = x.number_of_digits
      output_base = rounding.base

      # here rounding_mode is not the output rounding mode, but the rounding mode used for input
      rounding_mode = (@input_rounding || rounding).mode

      formatter = Flt::Support::Formatter.new(
        @context.radix, @context.etiny, output_base, raise_on_repeat: false
      )
      formatter.format(
        x, coefficient, exponent, rounding_mode, precision, all_digits
      )

      dec_pos, digits = formatter.digits
      rep_pos = formatter.repeat

      normalization = :approximate

      numeral = Numerals::Numeral[digits, sign: sign, point: dec_pos, rep_pos: rep_pos, base: output_base, normalize: normalization]

      numeral = rounding.round(numeral, round_up: formatter.round_up)

      numeral
    end

    def special_numeral_to_num(numeral)
      case numeral.special
      when :nan
        @context.nan
      when :inf
        @context.infinity numeral.sign
      end
    end

    def fixed_numeral_to_num(numeral)
      # consider:
      # return exact_numeral_to_num(numeral) if numeral.exact?
      if numeral.base == @context.radix
        unless @context.exact?
          rounding = Rounding[@context.rounding, precision: @context.precision, base: @context.radix]
          numeral = rounding.round(numeral)
        end
        same_base_numeral_to_num numeral
      else
        if numeral.repeating? # numeral.exact?
          exact_numeral_to_num(numeral)
        else
          general_numeral_to_num numeral, :fixed
        end
      end
    end

    def same_base_numeral_to_num(numeral)
      sign, coefficient, scale = numeral.split
      @context.Num sign, coefficient, scale
    end

    def exact_numeral_to_num(numeral)
      @context.Num Rational(*numeral.to_quotient), :fixed
    end

    def free_numeral_to_num(numeral)
      if numeral.base == @context.radix
        same_base_numeral_to_num numeral
      else
        general_numeral_to_num numeral, :free
      end
    end

    def short_numeral_to_num(numeral)
      general_numeral_to_num numeral, :short
    end

    def general_numeral_to_num(numeral, mode)
      sign, coefficient, scale = numeral.split
      reader = Flt::Support::Reader.new(mode: mode)
      if @input_rounding
        rounding_mode = @input_rounding.mode
      else
        rounding_mode = @context.rounding
      end
      reader.read(@context, rounding_mode, sign, coefficient, scale, numeral.base).tap do
        # @exact = reader.exact?
      end
    end

  end

  def (Flt::Num).numerals_conversion(options = {})
    Numerals::FltConversion.new(self, options)
  end

  class Flt::Num::ContextBase
    def numerals_conversion(options = {})
      Numerals::FltConversion.new(self, options)
    end
  end

end
