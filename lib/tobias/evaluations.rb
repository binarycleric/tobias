# frozen_string_literal: true

module Tobias
  module Evaluations
    def self.run(database, container, options)
      results = []
      results << WorkMem.new(database, container, options).run
      results
    end
  end
end