# frozen_string_literal: true

require "simplecov"
require "minitest/autorun"
require "maxprocs"

SimpleCov.start do
  add_filter "/test/"
  enable_coverage :branch
end

# Custom stub helper for Minitest 6 compatibility
# Minitest 6 removed Object#stub, so we implement our own
module StubHelper
  def stub_method(klass, method_name, return_value_or_proc)
    original = klass.method(method_name)
    silence_warnings do
      klass.define_singleton_method(method_name) do |*args, &block|
        if return_value_or_proc.is_a?(Proc)
          return_value_or_proc.call(*args)
        else
          return_value_or_proc
        end
      end
    end
    yield
  ensure
    silence_warnings do
      klass.define_singleton_method(method_name, original)
    end
  end

  private

  def silence_warnings
    original_verbose = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = original_verbose
  end
end
