require 'numerals/conversions'
require 'singleton'

class Numerals::IntegerConversion

  include Singleton

  class InvalidConversion < RuntimeError
  end

  def order_of_magnitude(value, options={})
    base = options[:base] || 10
    if base == 2 && value.respond_to?(:bit_length)
      value.bit_length
    else
      value.to_s(base).size
    end
  end

  def number_to_numeral(number, mode, rounding)
    # Rational.numerals_conversion Rational(number), mode, rounding
    numeral = Numeral.from_quotient(number, 1)
    numeral = rounding.round(numeral) unless rounding.exact?
    numeral
  end

  def numeral_to_number(numeral, mode)
    rational = Rational.numerals_conversion.numeral_to_number numeral, mode
    if rational.denominator != 1
      raise InvalidConversion, "Invalid numeral to rational conversion"
    end
    rational.numerator
  end

end

def Integer.numerals_conversion
  Numerals::IntegerConversion.instance
end
