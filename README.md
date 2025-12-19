# maxprocs-ruby

A lightweight Ruby gem that detects CPU quota from Linux cgroups and returns the appropriate number of processors.

This is a Ruby equivalent of Go's [uber-go/automaxprocs](https://github.com/uber-go/automaxprocs).

## Problem

Ruby's `Etc.nprocessors` does not consider cgroup CPU quota - it returns the host's CPU count. In container environments (e.g., Docker/Kubernetes), the actual available CPU count differs from the host's CPU count.

For example, this causes Puma/Sidekiq worker counts to be excessive, leading to CPU throttling.

```ruby
# On a 64-core host with 2 CPU limit container
Etc.nprocessors # => 64 (host CPUs, not what you want)
Maxprocs.count # => 2  (container limit, what you want)
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'maxprocs'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install maxprocs
```

## Synopsis

```ruby
require 'maxprocs'

# Get CPU count considering cgroup quota (Integer)
Maxprocs.count # => 2

# Get raw quota value (Float or nil)
Maxprocs.quota # => 2.5 (nil if unlimited)

# Check if CPU is limited
Maxprocs.limited? # => true/false

# Get cgroup version
Maxprocs.cgroup_version # => :v1, :v2, or :none

# Clear cache (for testing)
Maxprocs.reset!

# Rounding options
Maxprocs.count(round: :floor) # => 2
Maxprocs.count(round: :ceil) # => 3
```

## API Reference

| Method | Return Type | Description |
|--------|-------------|-------------|
| `Maxprocs.count(round:)` | `Integer` | CPU count (minimum 1). `round: :floor` (default) or `:ceil` |
| `Maxprocs.quota` | `Float` or `nil` | Raw quota value, `nil` if unlimited |
| `Maxprocs.limited?` | `Boolean` | `true` if CPU quota is set |
| `Maxprocs.cgroup_version` | `Symbol` | `:v1`, `:v2`, or `:none` |
| `Maxprocs.reset!` | `void` | Clear cached values |

Use `maxprocs` when you only need cgroup-aware CPU count detection and want to minimize dependencies.

## Limitations

- On macOS/Windows, always falls back to `Etc.nprocessors`
- cpu.shares not supported: Only `cpu.cfs_quota_us`/`cpu.max` are read (shares are relative weights, not absolute limits)
- Direct cgroup only: Does not traverse parent cgroups
- Some platforms return -1: Some environments may return unlimited quota

## Requirements

- Ruby 3.2+

## Development

```bash
bundle install
bundle exec rake
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/moznion/maxprocs-ruby.

## Related Projects

- [uber-go/automaxprocs](https://github.com/uber-go/automaxprocs) - Go implementation (inspiration for this gem)
- [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby) - Full-featured concurrency library with cgroup support
- [Go 1.25 GOMAXPROCS](https://github.com/golang/go/issues/73193) - Native Go runtime cgroup support

