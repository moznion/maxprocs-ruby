# frozen_string_literal: true

require_relative "../lib/maxprocs"
require "etc"

# E2E test script for verifying cgroup CPU detection in containers
#
# Environment variables:
#   EXPECTED_COUNT - Expected CPU count (required)
#   EXPECTED_LIMITED - Expected limited? value: "true" or "false" (optional)
#   EXPECTED_VERSION - Expected cgroup version: "v1", "v2", or "none" (optional)

class E2ETest
  def initialize
    @expected_count = ENV.fetch("EXPECTED_COUNT").to_i
    @expected_limited = ENV["EXPECTED_LIMITED"]
    @expected_version = ENV["EXPECTED_VERSION"]
    @failures = []
  end

  def run
    puts "=" * 60
    puts "maxprocs E2E Test"
    puts "=" * 60
    puts

    print_environment
    puts

    run_tests
    puts

    print_results
    exit(@failures.empty? ? 0 : 1)
  end

  private

  def print_environment
    puts "Environment:"
    puts "  Etc.nprocessors:      #{Etc.nprocessors}"
    puts "  Maxprocs.count:      #{Maxprocs.count}"
    puts "  Maxprocs.quota:      #{Maxprocs.quota.inspect}"
    puts "  Maxprocs.limited?:   #{Maxprocs.limited?}"
    puts "  Maxprocs.cgroup_version: #{Maxprocs.cgroup_version}"
    puts
    puts "cgroup files:"
    print_cgroup_files
  end

  def print_cgroup_files
    files = [
      "/proc/self/cgroup",
      "/sys/fs/cgroup/cgroup.controllers",
      "/sys/fs/cgroup/cpu.max",
      "/sys/fs/cgroup/cpu/cpu.cfs_quota_us",
      "/sys/fs/cgroup/cpu/cpu.cfs_period_us"
    ]

    files.each do |path|
      if File.exist?(path)
        content = File.read(path).strip.gsub("\n", "\\n")
        content = content[0, 50] + "..." if content.length > 50
        puts "  #{path}: #{content}"
      else
        puts "  #{path}: (not found)"
      end
    end
  end

  def run_tests
    puts "Tests:"

    # Test count
    actual_count = Maxprocs.count
    if actual_count == @expected_count
      puts "  [PASS] count: #{actual_count} == #{@expected_count}"
    else
      puts "  [FAIL] count: #{actual_count} != #{@expected_count}"
      @failures << "count: expected #{@expected_count}, got #{actual_count}"
    end

    # Test count with ceil
    actual_ceil = Maxprocs.count(round: :ceil)
    puts "  [INFO] count(round: :ceil): #{actual_ceil}"

    # Test limited? (optional)
    if @expected_limited
      expected = @expected_limited == "true"
      actual = Maxprocs.limited?
      if actual == expected
        puts "  [PASS] limited?: #{actual} == #{expected}"
      else
        puts "  [FAIL] limited?: #{actual} != #{expected}"
        @failures << "limited?: expected #{expected}, got #{actual}"
      end
    end

    # Test cgroup_version (optional)
    if @expected_version
      expected = @expected_version.to_sym
      actual = Maxprocs.cgroup_version
      if actual == expected
        puts "  [PASS] cgroup_version: #{actual} == #{expected}"
      else
        puts "  [FAIL] cgroup_version: #{actual} != #{expected}"
        @failures << "cgroup_version: expected #{expected}, got #{actual}"
      end
    end

    # Test quota is consistent with count
    quota = Maxprocs.quota
    if quota
      expected_floor = [quota.floor, 1].max
      if actual_count == expected_floor
        puts "  [PASS] count matches quota.floor (#{quota} -> #{expected_floor})"
      else
        puts "  [FAIL] count doesn't match quota.floor (#{quota} -> #{expected_floor}, got #{actual_count})"
        @failures << "count doesn't match quota calculation"
      end
    end
  end

  def print_results
    puts "=" * 60
    if @failures.empty?
      puts "Result: ALL TESTS PASSED"
    else
      puts "Result: #{@failures.size} TEST(S) FAILED"
      @failures.each { |f| puts "  - #{f}" }
    end
    puts "=" * 60
  end
end

E2ETest.new.run
