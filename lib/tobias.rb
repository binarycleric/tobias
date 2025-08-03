# frozen_string_literal: true

# Performance optimizations for Ruby
if RUBY_ENGINE == "ruby"
  # Optimize GC for high-throughput scenarios
  GC.start(full_mark: true, immediate_sweep: true) if GC.respond_to?(:start)

  # Configure for better concurrent performance
  if defined?(GC.compact)
    at_exit { GC.compact }
  end
end

require "bundler/setup"
Bundler.require(:default)

require "thor"
require "active_support/all"
require "sequel"
require "enumerable-stats"
require "benchmark"
require "tty-markdown"

$LOAD_PATH.unshift File.dirname(__FILE__)

module Tobias
  autoload :CLI, "tobias/cli"
  autoload :Container, "tobias/container"
  autoload :Evaluation, "tobias/evaluation"
  autoload :WorkMem, "tobias/work_mem"
end
