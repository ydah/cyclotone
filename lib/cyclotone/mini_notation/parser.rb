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
        @tokens = tokenize(input.to_s)
        @index = 0

        skip_spaces
        raise ParseError.new("input is empty", line: 1, column: 1) if current.type == :eof

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

          if SINGLE_CHAR_TOKENS.key?(char)
            tokens << Token.new(type: SINGLE_CHAR_TOKENS[char], value: char, line: line, column: column)
            index += 1
            column += 1
            next
          end

          if char.match?(/[0-9]/)
            start_index = index
            start_column = column
            while index < input.length && input[index].match?(/[0-9.]/)
              index += 1
              column += 1
            end

            tokens << Token.new(type: :number, value: input[start_index...index], line: line, column: start_column)
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
                   AST::Repeat.new(pattern: node, count: parse_integer)
                 when :bang
                   advance
                   AST::Replicate.new(pattern: node, count: parse_integer)
                 when :slash
                   advance
                   AST::Slow.new(pattern: node, amount: parse_number)
                 when :at
                   advance
                   AST::Elongate.new(pattern: node, amount: parse_number)
                 when :question
                   advance
                   probability = current.type == :number ? parse_number : 0.5
                   AST::Degrade.new(pattern: node, probability: probability)
                 when :colon
                   advance
                   sample = parse_integer
                   unless node.is_a?(AST::Atom)
                     raise parse_error("sample suffix can only be applied to atoms")
                   end

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
          numeric_value = token.value.include?(".") ? token.value.to_f : token.value.to_i
          AST::Atom.new(value: numeric_value)
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
        pulses = parse_integer
        expect(:comma)
        steps = parse_integer
        rotation = 0

        if accept(:comma)
          rotation = parse_integer
        end

        expect(:rparen)
        AST::Euclidean.new(pattern: node, pulses: pulses, steps: steps, rotation: rotation)
      end

      def parse_polymetric
        expect(:lbrace)
        patterns = [parse_sequence(terminators: [:comma, :rbrace])]

        while accept(:comma)
          patterns << parse_sequence(terminators: [:comma, :rbrace])
        end

        expect(:rbrace)
        steps = accept(:percent) ? parse_integer : nil

        AST::Polymetric.new(patterns: patterns, steps: steps)
      end

      def parse_number
        token = expect(:number)

        token.value.include?(".") ? token.value.to_f : token.value.to_i
      end

      def parse_integer
        expect(:number).value.to_i
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
        ParseError.new(message, line: current.line, column: current.column)
      end
    end
  end
end
