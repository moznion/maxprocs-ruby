# frozen_string_literal: true

# rbs_inline: enabled

require "etc"
require_relative "maxprocs/version"

# Maxprocs detects CPU quota from Linux cgroups and returns the appropriate
# number of processors for container environments.
module Maxprocs
  CGROUP_FILE_PATH = "/proc/self/cgroup"
  CGROUP_V1_QUOTA_PATH = "/sys/fs/cgroup/cpu/cpu.cfs_quota_us"
  CGROUP_V1_PERIOD_PATH = "/sys/fs/cgroup/cpu/cpu.cfs_period_us"
  CGROUP_V2_CONTROLLERS_PATH = "/sys/fs/cgroup/cgroup.controllers"
  CGROUP_V2_CPU_MAX_PATH = "/sys/fs/cgroup/cpu.max"

  @mutex = Mutex.new # Thread-safe memoization using a mutex
  @quota_cache = nil
  @version_cache = nil
  @initialized = false

  class << self
    # Returns the number of CPUs available, considering cgroup quota.
    #
    # @rbs round: Symbol -- :floor (default) or :ceil for rounding method
    # @rbs return: Integer -- the number of CPUs (minimum 1)
    def count(round: :floor)
      q = quota
      return Etc.nprocessors if q.nil?

      result = case round
      when :ceil
        q.ceil
      else
        q.floor
      end

      [result, 1].max
    end

    # Returns the raw CPU quota as a float.
    #
    # @rbs return: Float? -- the quota (e.g., 2.5 for 2.5 CPUs), or nil if unlimited
    def quota
      ensure_initialized
      @quota_cache
    end

    # Returns whether CPU is limited by cgroup.
    #
    # @rbs return: bool -- true if CPU quota is set
    def limited?
      !quota.nil?
    end

    # Returns the detected cgroup version.
    #
    # @rbs return: Symbol -- :v1, :v2, or :none
    def cgroup_version
      ensure_initialized
      @version_cache
    end

    # Clears the cached values. Useful for testing.
    #
    # @rbs return: void
    def reset!
      @mutex.synchronize do
        @quota_cache = nil
        @version_cache = nil
        @initialized = false
      end
    end

    private

    # @rbs return: void
    def ensure_initialized
      return if @initialized

      @mutex.synchronize do
        return if @initialized

        @version_cache = detect_cgroup_version
        @quota_cache = read_quota
        @initialized = true
      end
    end

    # @rbs return: Symbol
    def detect_cgroup_version
      return :none unless File.exist?(CGROUP_FILE_PATH)

      # Check for cgroup v2 first
      if File.exist?(CGROUP_V2_CONTROLLERS_PATH)
        return :v2
      end

      if File.exist?(CGROUP_V1_QUOTA_PATH)
        return :v1
      end

      :none
    end

    # @rbs return: Float?
    def read_quota
      case @version_cache
      when :v2
        read_quota_v2
      when :v1
        read_quota_v1
      end
    rescue Errno::ENOENT, Errno::EACCES, Errno::EINVAL
      # File doesn't exist, permission denied, or invalid - fallback to unlimited
      nil
    end

    # @rbs return: Float?
    def read_quota_v1
      quota = File.read(CGROUP_V1_QUOTA_PATH).strip.to_i
      return nil if quota == -1 # -1 means unlimited

      period = File.read(CGROUP_V1_PERIOD_PATH).strip.to_i
      return nil if period <= 0

      quota.to_f / period
    end

    # @rbs return: Float?
    def read_quota_v2
      content = File.read(CGROUP_V2_CPU_MAX_PATH).strip
      parts = content.split

      max_str = parts[0]
      return nil if max_str == "max" # "max" means unlimited

      period_str = parts[1]
      return nil if period_str.nil?

      max = max_str.to_f
      period = period_str.to_f
      return nil if period <= 0

      max / period
    end
  end
end
