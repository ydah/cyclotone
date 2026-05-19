# frozen_string_literal: true

module Cyclotone
  module MiniNotation
    class Parser
      Token = Struct.new(:type, :value, :line, :column, keyword_init: true)

      SINGLE_CHAR_TOKENS = {
        "[" => :lbracket,
        "]" => :rbracket,
        "{" => :lbrace,
        "}" => :rbrace,
        "(" => :lparen,
        ")" => :rparen,
        "," => :comma,
        "." => :dot,
        "~" => :tilde,
        "*" => :star,
        "/" => :slash,
        "!" => :bang,
        "_" => :underscore,
        "@" => :at,
        "?" => :question,
        "|" => :pipe,
        ":" => :colon,
        "%" => :percent
      }.freeze

      def parse(input)
        @source = input.to_s
        @tokens = tokenize(@source)
        @index = 0

        skip_spaces
        raise ParseError.new("input is empty", line: 1, column: 1, source: @source) if current.type == :eof

        ast = parse_stack(terminators: [:eof])
        skip_spaces
        expect(:eof)
        ast
      end

      private

      def tokenize(input)
        tokens = []
        line = 1
        column = 1
        index = 0

        while index < input.length
          char = input[index]

          if char.match?(/\s/)
            start_column = column
            while index < input.length && input[index].match?(/\s/)
              if input[index] == "\n"
                line += 1
                column = 1
              else
                column += 1
              end
              index += 1
            end

            tokens << Token.new(type: :space, value: " ", line: line, column: start_column)
            next
          end

          if char == "<"
            if input[index + 1] == ">"
              tokens << Token.new(type: :choice_gap, value: "<>", line: line, column: column)
              index += 2
              column += 2
            else
              tokens << Token.new(type: :langle, value: char, line: line, column: column)
              index += 1
              column += 1
            end
            next
          end

          if char == ">"
            tokens << Token.new(type: :rangle, value: char, line: line, column: column)
            index += 1
            column += 1
            next
          end

          if char.match?(/[0-9]/) || (char == "-" && input[index + 1]&.match?(/[0-9]/))
            token, index, column = tokenize_number(input, index, line, column)
            tokens << token
            next
          end

          if SINGLE_CHAR_TOKENS.key?(char)
            tokens << Token.new(type: SINGLE_CHAR_TOKENS[char], value: char, line: line, column: column)
            index += 1
            column += 1
            next
          end

          if %w[" '].include?(char)
            token, index, column = tokenize_quoted(input, index, line, column)
            tokens << token
            next
          end

          start_index = index
          start_column = column

          while index < input.length
            current_char = input[index]
            break if current_char.match?(/\s/) || SINGLE_CHAR_TOKENS.key?(current_char) || %w[< >].include?(current_char)

            index += 1
            column += 1
          end

          value = input[start_index...index]
          tokens << Token.new(type: :word, value: value, line: line, column: start_column)
        end

        tokens << Token.new(type: :eof, value: nil, line: line, column: column)
        tokens
      end

      def parse_stack(terminators:)
        patterns = [parse_choice(terminators: terminators + [:comma])]
        skip_spaces

        while accept(:comma)
          skip_spaces
          raise parse_error("empty stack branch") if terminators.include?(current.type) || current.type == :comma

          patterns << parse_choice(terminators: terminators + [:comma])
          skip_spaces
        end

        return patterns.first if patterns.length == 1

        AST::Stack.new(patterns: patterns)
      end

      def parse_choice(terminators:)
        patterns = [parse_sequence(terminators: terminators + [:pipe])]
        skip_spaces

        while accept(:pipe)
          skip_spaces
          raise parse_error("empty choice branch") if terminators.include?(current.type) || current.type == :pipe

          patterns << parse_sequence(terminators: terminators + [:pipe])
          skip_spaces
        end

        return patterns.first if patterns.length == 1

        AST::Choice.new(patterns: patterns)
      end

      def parse_sequence(terminators:)
        groups = []
        current_group = []

        loop do
          skip_spaces
          break if terminators.include?(current.type)

          if accept(:dot)
            groups << build_group(current_group)
            current_group = []
            next
          end

          if accept(:underscore)
            raise parse_error("unexpected underscore") if current_group.empty?

            current_group[-1] = if current_group[-1].is_a?(AST::Elongate)
                                  current_group[-1].increment
                                else
                                  AST::Elongate.new(pattern: current_group[-1], amount: 2)
                                end
            next
          end

          current_group << parse_term
        end

        groups << build_group(current_group) unless current_group.empty?
        raise parse_error("expected a pattern") if groups.empty?

        return groups.first if groups.length == 1

        AST::Sequence.new(elements: groups)
      end

      def parse_term
        node = parse_primary

        loop do
          skip_spaces

          node = case current.type
                 when :star
                   advance
                   AST::Repeat.new(pattern: node, count: parse_positive_integer("repeat count"))
                 when :bang
                   advance
                   AST::Replicate.new(pattern: node, count: parse_positive_integer("replicate count"))
                 when :slash
                   advance
                   AST::Slow.new(pattern: node, amount: parse_positive_number("slow amount"))
                 when :at
                   advance
                   AST::Elongate.new(pattern: node, amount: parse_positive_number("elongate amount"))
                 when :question
                   advance
                   probability = if current.type == :number
                                   parse_probability
                                 elsif implicit_probability_token?(current.type)
                                   0.5
                                 else
                                   raise parse_error("probability must be between 0 and 1")
                                 end
                   AST::Degrade.new(pattern: node, probability: probability)
                 when :colon
                   advance
                   sample = parse_non_negative_integer("sample number")
                   raise parse_error("sample suffix can only be applied to atoms") unless node.is_a?(AST::Atom)

                   node.with_sample(sample)
                 when :lparen
                   parse_euclidean(node)
                 else
                   break
                 end
        end

        node
      end

      def parse_primary
        token = current

        case token.type
        when :word
          advance
          AST::Atom.new(value: token.value)
        when :number
          advance
          AST::Atom.new(value: number_value(token.value))
        when :tilde
          advance
          AST::Rest.new
        when :lbracket
          advance
          node = parse_stack(terminators: [:rbracket])
          expect(:rbracket)
          node
        when :langle
          advance
          node = parse_sequence(terminators: [:rangle])
          expect(:rangle)
          AST::Alternating.new(patterns: unwrap(node))
        when :lbrace
          parse_polymetric
        else
          raise parse_error("unexpected token #{token.type}")
        end
      end

      def parse_euclidean(node)
        expect(:lparen)
        pulses = parse_non_negative_integer("euclidean pulses")
        expect(:comma)
        steps = parse_positive_integer("euclidean steps")
        rotation = 0

        rotation = parse_integer("euclidean rotation") if accept(:comma)

        expect(:rparen)
        AST::Euclidean.new(pattern: node, pulses: pulses, steps: steps, rotation: rotation)
      end

      def parse_polymetric
        expect(:lbrace)
        raise parse_error("empty polymetric branch") if current.type == :rbrace

        patterns = [parse_sequence(terminators: %i[comma rbrace])]

        while accept(:comma)
          raise parse_error("empty polymetric branch") if %i[comma rbrace].include?(current.type)

          patterns << parse_sequence(terminators: %i[comma rbrace])
        end

        expect(:rbrace)
        steps = accept(:percent) ? parse_positive_integer("polymetric steps") : nil

        AST::Polymetric.new(patterns: patterns, steps: steps)
      end

      def parse_number
        token = expect(:number)

        number_value(token.value)
      end

      def parse_integer(label = "integer")
        token = expect(:number)
        raise parse_error("#{label} must be an integer") if token.value.include?(".") || token.value.include?("/")

        token.value.to_i
      end

      def parse_positive_number(label)
        value = parse_number
        raise parse_error("#{label} must be positive") unless value.positive?

        value
      end

      def parse_probability
        value = parse_number
        raise parse_error("probability must be between 0 and 1") unless value.between?(0, 1)

        value
      end

      def parse_positive_integer(label)
        value = parse_integer(label)
        raise parse_error("#{label} must be positive") unless value.positive?

        value
      end

      def parse_non_negative_integer(label)
        value = parse_integer(label)
        raise parse_error("#{label} must be non-negative") if value.negative?

        value
      end

      def build_group(elements)
        raise parse_error("empty group") if elements.empty?

        return elements.first if elements.length == 1

        AST::Sequence.new(elements: elements)
      end

      def unwrap(node)
        return node.elements if node.is_a?(AST::Sequence)

        [node]
      end

      def current
        @tokens[@index]
      end

      def advance
        token = current
        @index += 1
        token
      end

      def accept(type)
        return false unless current.type == type

        advance
        true
      end

      def expect(type)
        return advance if current.type == type

        raise parse_error("expected #{type}, got #{current.type}")
      end

      def skip_spaces
        advance while current.type == :space
      end

      def parse_error(message)
        ParseError.new(message, line: current.line, column: current.column, source: @source)
      end

      def implicit_probability_token?(type)
        %i[
          space eof rbracket rangle rbrace comma pipe dot star bang slash at question colon lparen
        ].include?(type)
      end

      def tokenize_number(input, index, line, column)
        start_index = index
        start_column = column

        if input[index] == "-"
          index += 1
          column += 1
        end

        while index < input.length && input[index].match?(/[0-9]/)
          index += 1
          column += 1
        end

        if input[index] == "."
          unless input[index + 1]&.match?(/[0-9]/)
            raise ParseError.new("invalid number literal", line: line, column: column, source: @source)
          end

          index += 1
          column += 1

          while index < input.length && input[index].match?(/[0-9]/)
            index += 1
            column += 1
          end
        end

        raise ParseError.new("invalid number literal", line: line, column: column, source: @source) if input[index] == "."

        if input[index] == "/" && input[index + 1]&.match?(/[0-9]/)
          index += 1
          column += 1
          denominator_start = index

          while index < input.length && input[index].match?(/[0-9]/)
            index += 1
            column += 1
          end

          if input[denominator_start...index].to_i.zero?
            raise ParseError.new("rational denominator must be positive", line: line, column: denominator_start + 1, source: @source)
          end
        end

        [Token.new(type: :number, value: input[start_index...index], line: line, column: start_column), index, column]
      end

      def number_value(value)
        return Rational(value) if value.include?("/")
        return value.to_f if value.include?(".")

        value.to_i
      end

      def tokenize_quoted(input, index, line, column)
        quote = input[index]
        start_column = column
        index += 1
        column += 1
        value = +""

        while index < input.length
          char = input[index]

          if char == quote
            index += 1
            column += 1
            return [Token.new(type: :word, value: value, line: line, column: start_column), index, column]
          end

          if char == "\\"
            index += 1
            column += 1
            raise ParseError.new("unterminated escape sequence", line: line, column: column, source: @source) if index >= input.length

            char = input[index]
          end

          value << char
          index += 1
          column += 1
        end

        raise ParseError.new("unterminated quoted atom", line: line, column: start_column, source: @source)
      end
    end
  end
end
