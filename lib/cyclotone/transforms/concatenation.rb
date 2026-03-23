# frozen_string_literal: true

module Cyclotone
  module Transforms
    module Concatenation
      def append(other)
        Pattern.append(self, other)
      end

      def fast_append(other)
        Pattern.fast_append(self, other)
      end
    end
  end
end
