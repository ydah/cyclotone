# frozen_string_literal: true

module Cyclotone
  module MiniNotation
    class Compiler
      def compile(node)
        case node
        when AST::Atom
          compile_atom(node)
        when AST::Rest
          Pattern.silence
        when AST::Sequence
          compile_sequence(node)
        when AST::Stack
          Pattern.stack(node.patterns.map { |pattern| compile(pattern) })
        when AST::Alternating
          compile_alternating(node)
        when AST::Repeat
          compile(node.pattern).fast(node.count)
        when AST::Replicate
          Pattern.timecat(Array.new(node.count) { [1, compile(node.pattern)] })
        when AST::Slow
          compile(node.pattern).slow(node.amount)
        when AST::Elongate
          compile(node.pattern).slow(node.amount)
        when AST::Degrade
          compile(node.pattern).degrade_by(node.probability)
        when AST::Choice
          Pattern.randcat(node.patterns.map { |pattern| compile(pattern) })
        when AST::Euclidean
          compile_euclidean(node)
        when AST::Polymetric
          Pattern.stack(node.patterns.map { |pattern| compile(pattern) })
        else
          raise ArgumentError, "unsupported AST node #{node.class}"
        end
      end

      private

      def compile_atom(node)
        if node.sample
          Pattern.pure({ s: node.value, n: node.sample })
        else
          Pattern.pure(node.value)
        end
      end

      def compile_sequence(node)
        Pattern.timecat(node.elements.map { |element| compile_weighted(element) })
      end

      def compile_weighted(node)
        if node.is_a?(AST::Elongate)
          [node.amount, compile(node.pattern)]
        else
          [1, compile(node)]
        end
      end

      def compile_alternating(node)
        patterns = node.patterns.map { |pattern| compile(pattern) }

        Pattern.new do |span|
          cycle = span.cycle_number
          patterns[cycle % patterns.length].query_span(span)
        end
      end

      def compile_euclidean(node)
        gates = Euclidean.generate(node.pulses, node.steps, node.rotation)
        Pattern.timecat(
          gates.map do |gate|
            [1, gate ? compile(node.pattern) : Pattern.silence]
          end
        )
      end
    end
  end
end
