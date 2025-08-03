# frozen_string_literal: true

module Tobias
  class WorkMem
    attr_reader :amount

    def initialize(amount)
      @amount = amount
    end

    def >(other)
      @amount > other.amount
    end

    def <(other)
      @amount < other.amount
    end

    def >=(other)
      @amount >= other.amount
    end

    def <=(other)
      @amount <= other.amount
    end

    def <=>(other)
      @amount <=> other.amount
    end

    def to_sql
      case @amount
      when 0...1024
        "#{@amount}B"
      when 1024...1048576
        kb = @amount / 1024.0
        kb == kb.to_i ? "#{kb.to_i}kB" : "#{kb}kB"
      when 1048576...1073741824
        mb = @amount / 1048576.0
        mb == mb.to_i ? "#{mb.to_i}MB" : "#{mb}MB"
      else
        gb = @amount / 1073741824.0
        gb == gb.to_i ? "#{gb.to_i}GB" : "#{gb}GB"
      end
    end

    def inspect
      to_sql
    end

    def self.all
      [
        new(64.kilobytes),
        new(128.kilobytes),
        new(512.kilobytes),
        new(1.megabyte),
        new(4.megabytes),
        new(8.megabytes),
        new(16.megabytes),
        new(32.megabytes),
        new(64.megabytes),
        new(128.megabytes),
        new(256.megabytes),
        new(512.megabytes),
        new(1.gigabyte),
        new(2.gigabytes),
        new(4.gigabytes),
        new(8.gigabytes),
      ]
    end
  end
end