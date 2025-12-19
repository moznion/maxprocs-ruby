# frozen_string_literal: true

require "test_helper"

class MaxprocsTest < Minitest::Test
  include StubHelper

  def setup
    Maxprocs.reset!
  end

  def test_count_returns_correct_cpu_count_with_floor_rounding_for_v2
    stub_cgroup_v2("250000 100000\n") do
      assert_equal 2, Maxprocs.count
    end
  end

  def test_count_returns_correct_cpu_count_with_ceil_rounding_for_v2
    stub_cgroup_v2("250000 100000\n") do
      assert_equal 3, Maxprocs.count(round: :ceil)
    end
  end

  def test_count_returns_minimum_of_1_for_small_quota
    stub_cgroup_v2("50000 100000\n") do
      assert_equal 1, Maxprocs.count
    end
  end

  def test_count_returns_correct_cpu_count_for_v1
    stub_cgroup_v1("300000\n", "100000\n") do
      assert_equal 3, Maxprocs.count
    end
  end

  def test_count_falls_back_to_etc_nprocessors_for_v1_unlimited_quota
    stub_cgroup_v1("-1\n", "100000\n") do
      stub_method(Etc, :nprocessors, 8) do
        assert_equal 8, Maxprocs.count
      end
    end
  end

  def test_count_falls_back_to_etc_nprocessors_for_v2_unlimited_quota
    stub_cgroup_v2("max 100000\n") do
      stub_method(Etc, :nprocessors, 16) do
        assert_equal 16, Maxprocs.count
      end
    end
  end

  def test_count_falls_back_to_etc_nprocessors_when_no_cgroup
    stub_no_cgroup do
      stub_method(Etc, :nprocessors, 4) do
        assert_equal 4, Maxprocs.count
      end
    end
  end

  def test_count_falls_back_to_etc_nprocessors_when_file_read_fails
    exist_stub = ->(path) {
      ["/proc/self/cgroup", Maxprocs::CGROUP_V2_CONTROLLERS_PATH].include?(path)
    }

    read_stub = ->(_path) { raise Errno::EACCES }

    stub_method(File, :exist?, exist_stub) do
      stub_method(File, :read, read_stub) do
        stub_method(Etc, :nprocessors, 8) do
          assert_equal 8, Maxprocs.count
        end
      end
    end
  end

  def test_quota_returns_quota_as_float
    stub_cgroup_v2("250000 100000\n") do
      assert_equal 2.5, Maxprocs.quota
    end
  end

  def test_quota_returns_nil_when_unlimited
    stub_cgroup_v2("max 100000\n") do
      assert_nil Maxprocs.quota
    end
  end

  def test_limited_returns_true_when_quota_is_set
    stub_cgroup_v2("200000 100000\n") do
      assert Maxprocs.limited?
    end
  end

  def test_limited_returns_false_when_quota_is_unlimited
    stub_cgroup_v2("max 100000\n") do
      refute Maxprocs.limited?
    end
  end

  def test_cgroup_version_returns_v2
    stub_cgroup_v2("200000 100000\n") do
      assert_equal :v2, Maxprocs.cgroup_version
    end
  end

  def test_cgroup_version_returns_v1
    stub_cgroup_v1("200000\n", "100000\n") do
      assert_equal :v1, Maxprocs.cgroup_version
    end
  end

  def test_cgroup_version_returns_none
    stub_no_cgroup do
      assert_equal :none, Maxprocs.cgroup_version
    end
  end

  def test_reset_clears_cached_values
    stub_cgroup_v2("200000 100000\n") do
      assert_equal 2, Maxprocs.count
    end

    Maxprocs.reset!

    stub_cgroup_v2("400000 100000\n") do
      assert_equal 4, Maxprocs.count
    end
  end

  def test_memoization_only_reads_files_once
    read_count = 0

    exist_stub = ->(path) {
      ["/proc/self/cgroup", Maxprocs::CGROUP_V2_CONTROLLERS_PATH].include?(path)
    }

    read_stub = ->(path) {
      if path == Maxprocs::CGROUP_V2_CPU_MAX_PATH
        read_count += 1
        "200000 100000\n"
      else
        raise "unexpected file name"
      end
    }

    stub_method(File, :exist?, exist_stub) do
      stub_method(File, :read, read_stub) do
        Maxprocs.count
        Maxprocs.count
        Maxprocs.quota
        Maxprocs.limited?
      end
    end

    assert_equal 1, read_count
  end

  def test_falls_back_when_period_is_zero_in_v1
    stub_cgroup_v1("200000\n", "0\n") do
      stub_method(Etc, :nprocessors, 4) do
        assert_equal 4, Maxprocs.count
      end
    end
  end

  def test_falls_back_when_period_is_zero_in_v2
    stub_cgroup_v2("200000 0\n") do
      stub_method(Etc, :nprocessors, 4) do
        assert_equal 4, Maxprocs.count
      end
    end
  end

  def test_falls_back_when_cpu_max_has_missing_period
    stub_cgroup_v2("200000\n") do
      stub_method(Etc, :nprocessors, 4) do
        assert_equal 4, Maxprocs.count
      end
    end
  end

  private

  def stub_cgroup_v2(cpu_max_content)
    exist_stub = ->(path) {
      ["/proc/self/cgroup", Maxprocs::CGROUP_V2_CONTROLLERS_PATH].include?(path)
    }

    read_stub = ->(path) {
      case path
      when Maxprocs::CGROUP_V2_CPU_MAX_PATH
        cpu_max_content
      else
        raise "unexpected file name"
      end
    }

    stub_method(File, :exist?, exist_stub) do
      stub_method(File, :read, read_stub) do
        yield
      end
    end
  end

  def stub_cgroup_v1(quota_content, period_content)
    exist_stub = ->(path) {
      ["/proc/self/cgroup", Maxprocs::CGROUP_V1_QUOTA_PATH].include?(path)
    }

    read_stub = ->(path) {
      case path
      when Maxprocs::CGROUP_V1_QUOTA_PATH
        quota_content
      when Maxprocs::CGROUP_V1_PERIOD_PATH
        period_content
      else
        raise "unexpected file name"
      end
    }

    stub_method(File, :exist?, exist_stub) do
      stub_method(File, :read, read_stub) do
        yield
      end
    end
  end

  def stub_no_cgroup
    exist_stub = ->(_path) { false }

    stub_method(File, :exist?, exist_stub) do
      yield
    end
  end
end
