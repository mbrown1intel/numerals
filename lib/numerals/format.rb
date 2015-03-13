module Numerals

  class Format

    def initialize(*args)
      @exact_input = false
      @rounding = Rounding[]
      set! *args
    end

    attr_reader :rounding, :exact_input

    def base
      @rounding.base
    end

    include ModalSupport::StateEquivalent

    def [](*args)
      set *args
    end

    def self.[](*args)
      Format.new *args
    end

    def set!(*args)
      options = extract_options(*args)
      @exact_input = options[:exact_input] if options.has_key?(:exact_input)
      @rounding.set! base: options[:base] if options[:base]
      @rounding.set! options[:rounding] if options[:rounding]
      normalize!
    end

    def set(*args)
      dup.set! *args
    end

    def parameters
      {
        rounding: @rounding,
        exact_input: @exact_input
      }
    end

    def set_rounding(*args)
      dup.set_rounding!(*args)
    end

    def set_rounding!(*args)
      set! rounding: args
    end

    def set_base!(base)
      set! base: base
    end

    def set_base(base)
      dup.set_base(base)
    end

    def set_exact_input!(value)
      @exact_input = value
      normalize!
    end

    def set_exact_input(value)
      dup.set_exact_input!(value)
    end

    def dup
      # we need deep copy
      Format[parameters]
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
        when Format
          options.merge arg.parameters
        when :exact_input
          options[:exact_input] = true
        else
          raise "Invalid Format definition"
        end
      end
      options
    end

    def normalize!
      self
    end

  end

end
