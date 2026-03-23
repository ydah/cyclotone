# frozen_string_literal: true

module Cyclotone
  class Error < StandardError; end

  class ParseError < Error
    attr_reader :line, :column

    def initialize(message, line: nil, column: nil)
      @line = line
      @column = column

      super(format_message(message))
    end

    private

    def format_message(message)
      return message unless line && column

      "#{message} at line #{line}, column #{column}"
    end
  end

  class ConnectionError < Error; end
  class InvalidControlError < Error; end
end
