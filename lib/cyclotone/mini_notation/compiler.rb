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
          compile_polymetric(node)
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

      def compile_polymetric(node)
        base_steps = (node.steps || step_count(node.patterns.first)).to_i
        base_steps = 1 if base_steps <= 0

        Pattern.stack(
          node.patterns.map do |pattern|
            pattern_steps = [step_count(pattern), 1].max
            compile(pattern).slow(Rational(pattern_steps, base_steps))
          end
        )
      end

      def step_count(node)
        case node
        when AST::Atom, AST::Rest
          1
        when AST::Sequence
          node.elements.sum { |element| step_count(element) }
        when AST::Stack, AST::Alternating, AST::Choice
          node.patterns.map { |pattern| step_count(pattern) }.max || 1
        when AST::Repeat, AST::Replicate
          step_count(node.pattern) * node.count
        when AST::Slow, AST::Degrade
          step_count(node.pattern)
        when AST::Elongate
          step_count(node.pattern) * node.amount.to_i
        when AST::Euclidean
          [node.steps, 1].max * step_count(node.pattern)
        when AST::Polymetric
          node.steps || step_count(node.patterns.first)
        else
          1
        end
      end
    end
  end
end
