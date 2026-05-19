# frozen_string_literal: true

module Cyclotone
  class Error < StandardError; end

  class ParseError < Error
    attr_reader :line, :column, :source

    def initialize(message, line: nil, column: nil, source: nil)
      @line = line
      @column = column
      @source = source

      super(format_message(message))
    end

    private

    def format_message(message)
      return message unless line && column
      return "#{message} at line #{line}, column #{column}" unless source

      source_line = source.lines.fetch(line - 1, "").chomp
      caret = "#{" " * [column - 1, 0].max}^"
      "#{message} at line #{line}, column #{column}\n#{source_line}\n#{caret}"
    end
  end

  class ConnectionError < Error; end
  class InvalidControlError < Error; end
  class InvalidRationalError < Error; end
end
