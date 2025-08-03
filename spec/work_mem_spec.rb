# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tobias::WorkMem do
  describe "#initialize" do
    it "stores the amount in bytes" do
      work_mem = described_class.new(1024)
      expect(work_mem.instance_variable_get(:@amount)).to eq(1024)
    end

    it "accepts integer amounts" do
      work_mem = described_class.new(2048)
      expect(work_mem.instance_variable_get(:@amount)).to eq(2048)
    end

    it "accepts float amounts" do
      work_mem = described_class.new(1536.5)
      expect(work_mem.instance_variable_get(:@amount)).to eq(1536.5)
    end
  end

  describe "#to_sql" do
    context "when amount is in bytes (< 1024)" do
      it "formats small values in bytes" do
        work_mem = described_class.new(512)
        expect(work_mem.to_sql).to eq("512B")
      end

      it "formats zero bytes" do
        work_mem = described_class.new(0)
        expect(work_mem.to_sql).to eq("0B")
      end

      it "formats single byte" do
        work_mem = described_class.new(1)
        expect(work_mem.to_sql).to eq("1B")
      end

      it "formats boundary value (1023 bytes)" do
        work_mem = described_class.new(1023)
        expect(work_mem.to_sql).to eq("1023B")
      end
    end

    context "when amount is in kilobytes (1024 - 1048575)" do
      it "formats exact kilobytes as integers" do
        work_mem = described_class.new(1024)
        expect(work_mem.to_sql).to eq("1kB")
      end

      it "formats multiple kilobytes" do
        work_mem = described_class.new(64 * 1024)
        expect(work_mem.to_sql).to eq("64kB")
      end

      it "formats non-integer kilobytes with decimal" do
        work_mem = described_class.new(1536) # 1.5kB
        expect(work_mem.to_sql).to eq("1.5kB")
      end

      it "formats boundary value (1048575 bytes)" do
        work_mem = described_class.new(1048575)
        expect(work_mem.to_sql).to match(/1023\.\d+kB/)
      end
    end

    context "when amount is in megabytes (1048576 - 1073741823)" do
      it "formats exact megabytes as integers" do
        work_mem = described_class.new(1048576)
        expect(work_mem.to_sql).to eq("1MB")
      end

      it "formats multiple megabytes" do
        work_mem = described_class.new(16 * 1048576)
        expect(work_mem.to_sql).to eq("16MB")
      end

      it "formats non-integer megabytes with decimal" do
        work_mem = described_class.new(1572864) # 1.5MB
        expect(work_mem.to_sql).to eq("1.5MB")
      end

      it "formats large megabyte values" do
        work_mem = described_class.new(512 * 1048576)
        expect(work_mem.to_sql).to eq("512MB")
      end

      it "formats boundary value (1073741823 bytes)" do
        work_mem = described_class.new(1073741823)
        expect(work_mem.to_sql).to match(/1023\.\d+MB/)
      end
    end

    context "when amount is in gigabytes (>= 1073741824)" do
      it "formats exact gigabytes as integers" do
        work_mem = described_class.new(1073741824)
        expect(work_mem.to_sql).to eq("1GB")
      end

      it "formats multiple gigabytes" do
        work_mem = described_class.new(4 * 1073741824)
        expect(work_mem.to_sql).to eq("4GB")
      end

      it "formats non-integer gigabytes with decimal" do
        work_mem = described_class.new(1610612736) # 1.5GB
        expect(work_mem.to_sql).to eq("1.5GB")
      end

      it "formats large gigabyte values" do
        work_mem = described_class.new(8 * 1073741824)
        expect(work_mem.to_sql).to eq("8GB")
      end
    end

    context "with ActiveSupport byte helpers" do
      it "formats values created with .kilobytes helper" do
        work_mem = described_class.new(64.kilobytes)
        expect(work_mem.to_sql).to eq("64kB")
      end

      it "formats values created with .megabytes helper" do
        work_mem = described_class.new(16.megabytes)
        expect(work_mem.to_sql).to eq("16MB")
      end

      it "formats values created with .gigabytes helper" do
        work_mem = described_class.new(2.gigabytes)
        expect(work_mem.to_sql).to eq("2GB")
      end
    end
  end

  describe "#inspect" do
    it "returns the same value as to_sql" do
      work_mem = described_class.new(4.megabytes)
      expect(work_mem.inspect).to eq(work_mem.to_sql)
      expect(work_mem.inspect).to eq("4MB")
    end

    it "works with different sizes" do
      work_mem_kb = described_class.new(128.kilobytes)
      work_mem_gb = described_class.new(1.gigabyte)

      expect(work_mem_kb.inspect).to eq("128kB")
      expect(work_mem_gb.inspect).to eq("1GB")
    end
  end

  describe ".all" do
    let(:all_work_mems) { described_class.all }

    it "returns an array of WorkMem instances" do
      expect(all_work_mems).to be_an(Array)
      expect(all_work_mems).to all(be_a(described_class))
    end

    it "returns the expected number of instances" do
      expect(all_work_mems.size).to eq(16)
    end

    it "includes all expected values in correct format" do
      expected_values = [
        "64kB", "128kB", "512kB",
        "1MB", "4MB", "8MB", "16MB", "32MB", "64MB", "128MB", "256MB", "512MB",
        "1GB", "2GB", "4GB", "8GB"
      ]

      actual_values = all_work_mems.map(&:to_sql)
      expect(actual_values).to eq(expected_values)
    end

    it "creates instances with correct byte amounts" do
      expected_amounts = [
        64.kilobytes, 128.kilobytes, 512.kilobytes,
        1.megabyte, 4.megabytes, 8.megabytes, 16.megabytes, 32.megabytes,
        64.megabytes, 128.megabytes, 256.megabytes, 512.megabytes,
        1.gigabyte, 2.gigabytes, 4.gigabytes, 8.gigabytes
      ]

      actual_amounts = all_work_mems.map { |wm| wm.instance_variable_get(:@amount) }
      expect(actual_amounts).to eq(expected_amounts)
    end

    it "returns instances in ascending order" do
      amounts = all_work_mems.map { |wm| wm.instance_variable_get(:@amount) }
      expect(amounts).to eq(amounts.sort)
    end
  end

  describe "integration with PostgreSQL work_mem parameter" do
    it "generates valid PostgreSQL work_mem values" do
      work_mem = described_class.new(16.megabytes)
      sql_value = work_mem.to_sql

      # Should be in a format PostgreSQL accepts
      expect(sql_value).to match(/^\d+(\.\d+)?(B|kB|MB|GB)$/)
    end

    it "handles typical PostgreSQL work_mem ranges" do
      # Common PostgreSQL work_mem values
      typical_values = [
        described_class.new(4.megabytes),   # Default
        described_class.new(16.megabytes),  # Common tuned value
        described_class.new(64.megabytes),  # High-memory systems
        described_class.new(256.megabytes), # Data warehouse workloads
        described_class.new(1.gigabyte)     # Very large operations
      ]

      typical_values.each do |work_mem|
        expect(work_mem.to_sql).to match(/^\d+MB$|^\d+GB$/)
      end
    end
  end
end