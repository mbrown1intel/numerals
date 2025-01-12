module Numerals

  # A Format object holds formatting options and performs
  # formatted input/output operations on numbers.
  #
  # Formatting options are grouped into aspects:
  #
  # * Exact input
  # * Rounding
  # * Mode
  # * Symbols
  # * Input rounding
  #
  # Some aspects (Rounding, Mode & Symbols) are handled with aspect-definining
  # classes Rounding, Format::Mode and Format::Symbols.
  #
  # Exact input applies only to numeric types that can hold limited
  # precision values such as Float, Flt::Num or BigDecimal. It specifies
  # that the numeric value is to be taken as an exact quantity. Otherwise,
  # the numeric value is interpreted as a rounded approximation of some
  # original exact value (so it represents a range of exact number which
  # would all be rounded to the same approximation). Rational and Integer
  # types are always exact and not affected by this option.
  #
  # Rounding defines how numbers are rounded into text form or how
  # values represented in text round to numeric values. So it specifies
  # the precision of the result and whether the result is an approximation
  # or an exact quantity.
  #
  # Mode defines de formatting style.
  #
  # Symbols contains the details of how digits and other symbols are
  # represented in text form and the final text notation used.
  #
  # The input-rounding property can set to either a Rounding object
  # or just a rounding mode symbol (:half_even, etc.).
  # It is used to define which rounding mode is implied when reading textual
  # numeric expressions into approximate numeric values. It affects how
  # approximate numbers are written to text because the text representation
  # of approximate values should be read back into the original value.
  # If a Rounding object is assigned only the mode is used, and it is ignored
  # if the rounding is exact.  #
  #
  class Format < FormattingAspect

    def initialize(*args)
      @exact_input = false
      @rounding = Rounding[:short]
      @mode = Mode[]
      @symbols = Symbols[]
      @notation = :text
      @input_rounding = nil
      set!(*args)
    end

    attr_reader :rounding, :exact_input, :mode, :symbols, :notation,
                :input_rounding

    def base
      @rounding.base
    end

    def padding
      @symbols.padding
    end

    def padded?
      padding.padded?
    end

    # Presentation base for the significand
    def significand_base
      base**@mode.base_scale
    end

    include ModalSupport::StateEquivalent

    def input_rounding?
      !@input_rounding.nil?
    end

    def input_rounding_mode
      input_rounding? ? @input_rounding.mode : nil
    end

    set do |*args|
      options = extract_options(*args)
      @exact_input = options[:exact_input] if options.has_key?(:exact_input)
      @rounding.set! options[:rounding] if options[:rounding]
      @mode.set! options[:mode] if options[:mode] # :format ?
      @symbols.set! options[:symbols] if options[:symbols]
      @notation = options[:notation] if options[:notation]
      if options.has_key?(:input_rounding)
        set_input_rounding! options[:input_rounding]
      end

      # shortcuts
      @rounding.set! base: options[:base] if options[:base]
      @symbols.set! digits: options[:digits] if options[:digits]
      @rounding.set! mode: options[:rounding_mode] if options[:rounding_mode]
      @rounding.set! precision: options[:precision] if options[:precision]
      @rounding.set! places: options[:places] if options[:places]
      @symbols.set! repeating: options[:repeating] if options.has_key?(:repeating)
      @symbols.set! case_sensitive: options[:case_sensitive] if options.has_key?(:case_sensitive)
      @symbols.set! padding: options[:padding] if options[:padding]
    end

    def parameters
      {
        rounding: @rounding,
        exact_input: @exact_input,
        mode: @mode,
        symbols: @symbols,
        notation: @notation,
        input_rounding: input_rounding? ? @input_rounding : nil
      }
    end

    def to_s
      args = []
      args << "exact_input: true" if @exact_input
      args << "rounding: #{@rounding}"
      args << "mode: #{@mode}"
      args << "symbols: #{@symbols}"
      args << "notation: #{@notation.inspect}" if @notation != :text
      args << "input_rounding: #{input_rounding_mode.inspect}" if input_rounding?
      "Format[#{args.join(', ')}]"
    end

    def inspect
      to_s
    end

    def case_sensitive?
      @symbols.case_sensitive?
    end

    aspect :rounding do |*args|
      set! rounding: args
    end

    aspect :padding do |*args|
      set! padding: args
    end

    aspect :base do |base|
      set! base: base
    end

    aspect :exact_input do |value|
      @exact_input = value
    end

    aspect :mode do |*args|
      set! mode: args
    end

    aspect :symbols do |*args|
      set symbols: args
    end

    aspect :notation do |notation|
      set! notation: notation
    end

    aspect :digits do |digits|
      set! digits: digits
    end

    aspect :input_rounding do |input_roundig|
      if input_roundig.nil?
        @input_rounding = nil
      else
        if @input_rounding.nil?
          @input_rounding = Rounding[input_roundig]
        else
          @input_rounding.set! input_roundig
        end
      end
    end

    def dup
      # we need deep copy
      Format[parameters]
    end

    include Output
    include Input

    # Shortcuts to Symbols sub-aspects

    aspect :repeat do |*args|
      @symbols.set_repeat!(*args)
    end

    aspect :grouping do |*args|
      @symbols.set_grouping!(*args)
    end

    aspect :group_thousands do |sep = nil|
      @symbols.set_grouping!(sep)
    end

    aspect :signs do |plus, minus|
      @symbols.set_signs!(plus, minus)
    end

    aspect :plus do |plus, which = nil|
      @symbols.set_plus!(plus, which)
    end

    aspect :minus do |minus|
      @symbols.set_minus!(minus)
    end

    aspect :leading_zeros do |width|
      @symbols.set_leading_zeros! width
    end

    private

    def extract_options(*args)
      options = {}
      args = args.first if args.size == 1 && args.first.kind_of?(Array)
      args.each do |arg|
        case arg
        when Hash
          options.merge! arg
        when Rounding
          options[:rounding] = arg
        when Mode
          options[:mode] = arg
        when Symbols
          options[:symbols] = arg
        when Symbols::Digits
          options[:digits] = arg
        when Symbols::Padding
          options[:padding] = arg
        when Format
          options.merge! arg.parameters
        when :exact_input
          options[:exact_input] = true
        when :hexbin
          options.merge!(
            base: 2,
            mode: {
              base_scale: 4,
              mode: :scientific,
              sci_int_digits: 1
            },
            symbols: {
              exponent: 'p', base_prefix: '0x'
            }
          )
        when :gen, :general, :sci, :scientific, :fix, :fixed, :eng, :engineering
          options[:mode] = Mode[arg]
        when :short, :free, :simplify, :preserve
          options[:precision] = arg
        when  :half_even, :half_down, :half_up, :down, :up, :ceiling, :floor, :up05
          options[:rounding_mode] = arg
        when :case_sensitive
          options[:case_sensitive] = true
        when Symbol
          options[:notation] = arg
        when Integer
          options[:base] = arg
        else
          raise "Invalid Format definition"
        end
      end
      options
    end

  end

end
