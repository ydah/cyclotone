# frozen_string_literal: true

module Cyclotone
  module MiniNotation
    class Compiler
      MAX_EXPANSION = 4096

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
          validate_expansion_count(node.count, "repeat count")
          compile(node.pattern).fast(node.count)
        when AST::Replicate
          validate_expansion_count(node.count, "replicate count")
          Pattern.timecat(Array.new(node.count) { [1, compile(node.pattern)] })
        when AST::Slow, AST::Elongate
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
        raise ArgumentError, "alternating requires patterns" if patterns.empty?

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
        raise ArgumentError, "polymetric requires patterns" if node.patterns.empty?

        base_steps = Pattern.to_rational(node.steps || step_count(node.patterns.first))
        raise ArgumentError, "polymetric steps must be positive" unless base_steps.positive?

        Pattern.stack(
          node.patterns.map do |pattern|
            pattern_steps = [Pattern.to_rational(step_count(pattern)), Rational(1)].max
            compile(pattern).slow(pattern_steps / base_steps)
          end
        )
      end

      def step_count(node)
        case node
        when AST::Sequence
          node.elements.sum { |element| step_count(element) }
        when AST::Stack, AST::Alternating, AST::Choice
          node.patterns.map { |pattern| step_count(pattern) }.max || 1
        when AST::Repeat, AST::Replicate
          step_count(node.pattern) * node.count
        when AST::Slow, AST::Degrade
          step_count(node.pattern)
        when AST::Elongate
          Pattern.to_rational(step_count(node.pattern)) * Pattern.to_rational(node.amount)
        when AST::Euclidean
          [node.steps, 1].max * step_count(node.pattern)
        when AST::Polymetric
          node.steps || step_count(node.patterns.first)
        else
          1
        end
      end

      def validate_expansion_count(count, label)
        raise ArgumentError, "#{label} must be positive" unless count.positive?
        raise ArgumentError, "#{label} must be <= #{MAX_EXPANSION}" if count > MAX_EXPANSION
      end
    end
  end
end
