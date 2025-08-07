# frozen_string_literal: true

module Tobias
  class WorkMem
    attr_reader :amount

    def self.from_sql(sql)
      case sql
      when /^\d+B$/
        new(sql.to_i)
      when /^\d+kB$/
        new(sql.to_i * 1024)
      when /^\d+MB$/
        new(sql.to_i * 1024 * 1024)
      when /^\d+GB$/
        new(sql.to_i * 1024 * 1024 * 1024)
      else
        raise "Invalid work_mem setting: #{sql}"
      end
    end

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
        # new(64.kilobytes),
        # new(128.kilobytes),
        # new(256.kilobytes),
        # new(512.kilobytes),
        # new(1.megabyte),
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
      ].sort_by(&:amount)
    end

    # Inspects the database to determine the valid work_mem settings for the current user.
    # We'll need at least connection_limit / effective_cache_size for an optimal
    # work_mem setting, otherwise a user could run out of memory at max connections.
    def self.valid_for(database)
      role_conn_limit = database.select(:rolconnlimit).
        from(:pg_roles).
        where(rolname: Sequel.lit("current_user")).
        first

      max_connections = database.select(:setting).
        from(:pg_settings).
        where(name: "max_connections").
        first

      effective_cache_size = database.select(:setting, :unit).
        from(:pg_settings).
        where(name: "effective_cache_size").
        first

      effective_cache_size_bytes = effective_cache_size[:setting].to_i * 8 * 1024

      connection_limit = if role_conn_limit[:rolconnlimit] > 0
        role_conn_limit[:rolconnlimit]
      else
        max_connections[:setting].to_i
      end

      bytes_per_connection = effective_cache_size_bytes / connection_limit

      self.all.select { |work_mem| work_mem.amount < bytes_per_connection.to_i }
    end
  end
end
