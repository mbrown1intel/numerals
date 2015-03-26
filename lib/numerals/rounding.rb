module Numerals

  # Rounding of Numerals
  class Rounding < FormattingAspect

    # Rounding defined a rounding mode and a precision,
    # and is used to establish the desired accuracy of a Numeral result.
    #
    # Rounding also defines the base of the numerals to be rounded,
    # which is 10 by default.
    #
    # The rounding mode which is the rule used to limit
    # the precision of a numeral; the rounding modes available are those
    # of Flt::Num, namely:
    #
    # * :half_even
    # * :half_up
    # * :half_down
    # * :ceiling
    # * :floor
    # * :up
    # * :down
    # * :up05
    #
    # Regarding the rounding precision there are two types of Roundings:
    #
    # * Limited, fixed precision: the precision of the rounded result is either
    #   defined as relative (number of significant digits defined by the
    #   precision property) or absolute (number of fractional places
    #   --decimals for base 10-- defined by the places property)
    # * Unlimited, free precision which preserves the value of
    #   the input numeral. As much precision as needed is used to keep
    #   unambiguously the original value. When applied to exact input,
    #   this kind of rounding doesn't perform any rounding.
    #   For approximate input there are two variants:
    #   - Preserving the original value precision, which produces and
    #     approximate output. (All original digits are preserved;
    #     full precision mode). The :preserve symbol is used as the precision
    #     to define this kind of Rounding.
    #   - Simplifiying or reducing the result to produce an exact output
    #     without unneeded digits to restore the original value within its
    #     original precision (e.g. traling zeros are not keep).
    #     This case can be defined with the :simplify symbol for the precision.
    #
    # TODO: change :preserve/:simplify terms to :all/:short? :full/:reduced?
    #
    def initialize(*args)
      DEFAULTS.each do |param, value|
        instance_variable_set "@#{param}", value
      end
      set! *args
    end

    DEFAULTS = {
      mode: :half_even,
      precision: :simplify,
      places: nil,
      base: 10
    }

    attr_reader :mode, :base

    include ModalSupport::StateEquivalent

    set do |*args|
      options = extract_options(*args)
      options.each do |option, value|
        send :"#{option}=", value
      end
    end

    def base=(v)
      @base = v
    end

    def mode=(mode)
      @mode = mode
    end

    def precision=(v)
      @precision = v
      @precision = :simplify if v == 0
      @places = nil if @precision
    end

    def places=(v)
      @places = v
      @precision = nil if @places
    end

    def parameters
      if @precision
        { mode: @mode, precision: @precision, base: @base }
      else
        { mode: @mode, places: @places, base: @base }
      end
    end

    def to_s
      params = parameters
      DEFAULTS.each do |param, default|
        params.delete param if params[param] == default
      end
      "Rounding[#{params.inspect.unwrap('{}')}]"
    end

    def inspect
      to_s
    end

    # former exact? method
    def free? # unlimited? exact? all? nonrounding? free?
      [:simplify, :preserve].include?(@precision)
    end

    def fixed? # limited? approximate? rounding? fixed?
      !free?
    end

    def absolute?
      @precision.nil? # fixed? && @precision # !@places.nil?
    end

    def relative?
      fixed? && !absolute?
    end

    def simplifying?
      @precision == :simplify
    end

    def preserving?
      @precision == :preserve
    end

    # Number of significant digits for a given numerical/numeral value
    def precision(value = nil, options = {})
      if value.nil?
        @precision
      elsif free?
        if is_exact?(value, options)
          0
        else
          num_digits(value, options)
        end
      else # fixed?
        if absolute?
          @places + num_integral_digits(value)
        else # relative?
          @precision
        end
      end
    end

    # Number of fractional placesfor a given numerical/numeral value
    def places(value = nil, options = {})
      if value.nil?
        @places
      elsif is_exact?(value, options)
        @places || 0
      elsif free?
        num_digits(value, options) - num_integral_digits(value)
      else # fixed?
        if absolute?
          @places
        else # relative?
          @precision - num_integral_digits(value)
        end
      end
    end

    # Round a numeral. If the numeral has been truncated
    # the :round_up option must be used to pass the information
    # about the discarded digits:
    # * nil if all discarded digits where 0 (the truncated value is exact)
    # * :lo if there where non-zero discarded digits, but the first discarded digit
    #   is below half the base.
    # * :tie if the first discarded was half the base and there where no more nonzero digits,
    #   i.e. the original value was a 'tie', exactly halfway between the truncated value
    #   and the next value with the same number of digits.
    # * :hi if the original value was above the tie value.
    def round(numeral, options={})
      round_up = options[:round_up]
      numeral, round_up = truncate(numeral, round_up)
      adjust(numeral, round_up)
    end

    # Note: since Rounding has no mutable attributes, default dup is OK
    # otherwise we'd need to redefine it:
    # def dup
    #   Rounding[parameters]
    # end

    private

    def check_base(numeral)
      if numeral.base != @base
        raise "Invalid Numeral (base #{numeral.base}) for a base #{@base} Rounding"
      end
    end

    # Truncate a numeral and return also a round_up value with information about
    # the digits beyond the truncation point that can be used to round the truncated
    # numeral. If the numeral has already been truncated, the round_up result of
    # that prior truncation should be passed as the second argument.
    def truncate(numeral, round_up=nil)
      check_base numeral
      unless simplifying? # free?
        n = precision(numeral)
        infinite_n = (n == 0)
        unless (infinite_n || n >= numeral.digits.size) && numeral.approximate?
          if !infinite_n && (n < numeral.digits.size - 1)
            rest_digits = numeral.digits[n+1..-1]
          else
            rest_digits = []
          end
          if numeral.repeating? && numeral.repeat < numeral.digits.size &&
             (infinite_n || n >= numeral.repeat)
            rest_digits += numeral.digits[numeral.repeat..-1]
          end
          if infinite_n
            digits = numeral.digits[0..-1]
          else
            digits = numeral.digits[0, n]
          end
          if digits.size < n # TODO: infinite_n case
            digits += (digits.size...n).map{|i| numeral.digit_value_at(i)}
          end
          if numeral.base % 2 == 0
            tie_digit = numeral.base / 2
            max_lo = tie_digit - 1
          else
            max_lo = numeral.base / 2
          end
          next_digit = numeral.digit_value_at(n)
          if next_digit == 0
            unless round_up.nil? && rest_digits.all?{|d| d == 0}
              round_up = :lo
            end
          elsif next_digit <= max_lo # next_digit < tie_digit
            round_up = :lo
          elsif next_digit == tie_digit
            if round_up || rest_digits.any?{|d| d != 0}
              round_up = :hi
            else
              round_up = :tie
            end
          else # next_digit > tie_digit
            round_up = :hi
          end
          numeral = Numeral[digits, point: numeral.point, sign: numeral.sign, normalize: :approximate]
        end
      end
      [numeral, round_up]
    end

    # Adjust a truncated numeral using the round-up information
    def adjust(numeral, round_up)
      check_base numeral
      if numeral.exact? # simplifying?
        numeral.normalize! Numeral.exact_normalization
      else
        point, digits = Flt::Support.adjust_digits(
          numeral.point, numeral.digits.digits_array,
          round_mode: @mode,
          negative: numeral.sign == -1,
          round_up: round_up,
          base: numeral.base
        )
        if numeral.zero? && simplifying?
          digits = []
          point = 0
        end
        normalization = simplifying? ? :exact : :approximate
        Numeral[digits, point: point, base: numeral.base, sign: numeral.sign, normalize: normalization]
      end
    end

    ZERO_DIGITS = 0 # 1?

    # Number of digits in the integer part of the value (excluding leading zeros).
    def num_integral_digits(value)
      case value
      when 0
        ZERO_DIGITS
      when Numeral
        if value.zero?
          ZERO_DIGITS
        else
          if @base != value.base
            value = value.to_base(@base)
          end
          value.normalized(remove_trailing_zeros: true).point
        end
      else
        Conversions.order_of_magnitude(value, base: @base)
      end
    end

    def num_digits(value, options)
      case value
      when 0
        ZERO_DIGITS
      when Numeral
        if value.zero?
          ZERO_DIGITS
        else
          if @base != value.base
            value = value.to_base(@base)
          end
          if value.repeating?
            0
          else
            value.digits.size
          end
        end
      else
        Conversions.number_of_digits(value, options.merge(base: @base))
      end
    end

    def is_exact?(value, options={})
      case value
      when Numeral
        value.exact?
      else
        Conversions.exact?(value, options)
      end
    end

    def extract_options(*args)
      options = {}
      args = args.first if args.size == 1 && args.first.kind_of?(Array)
      args.each do |arg|
        case arg
        when Hash
          options.merge! arg
        when :simplify
          options.merge! precision: :simplify
        when :preserve
          options.merge! precision: :preserve
        when Symbol
          options[:mode] = arg
        when Integer
          options[:precision] = arg
        when Rounding
          options.merge! arg.parameters
        else
          raise "Invalid Rounding definition"
        end
      end
      options
    end

  end

end
