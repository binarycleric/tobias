# frozen_string_literal: true

module Tobias
  module Evaluations
    def self.run(container, options)
      results = []
      results << WorkMem.new(container, options).run
      results
    end
  end
end