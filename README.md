# TelemetryMetricsLogger

A [`telemetry_metrics`](https://github.com/beam-telemetry/telemetry_metrics) reporter that prints to the `Logger`.

This is different from the built-in console reporter for two reasons:

1. This reporter prints to the logger, instead of standard output
2. This reporter calculates metrics and prints a periodic report, instead of printing every configured event immediately

## Installation

This package can be installed by adding `telemetry_metrics_logger` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:telemetry_metrics_logger, "~> 0.1.0"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/telemetry_metrics_logger](https://hexdocs.pm/telemetry_metrics_logger).

## Usage

For example, imagine the given metrics:

```elixir
metrics = [
  last_value("vm.memory.binary", unit: :byte),
  counter("vm.memory.total"),
  summary("phoenix.endpoint.stop.duration", unit: {:native, :millisecond})
]
```

A this reporter can be started as a child of your supervision tree like this:

```elixir
{TelemetryMetricsLogger, metrics: metrics, interval: 60}
```

Then, every sixty seconds, you will see a report like this:

```
12:31:54.492 [info]  Telemetry report 2020-11-09T17:48:00Z
  Event [:vm, :memory]
    Measurement "binary"
      Last value: 100 B
    Measurement "total"
      Counter: 1
  Event [:phoenix, :endpoint, :stop]
    Measurement "duration"
      Summary:
        Average: 101 ms
        Min: 52 ms
        Max: 127 ms
```

## Maintainer

This project was developed by [Rosa Richter](https://github.com/Cantido).
You can get in touch with her on [Keybase.io](https://keybase.io/cantido).

## Contributing

Questions and pull requests are more than welcome.
I follow Elixir's tenet of bad documentation being a bug,
so if anything is unclear, please [file an issue](https://github.com/Cantido/telemetry_metrics_logger/issues/new)!
Ideally, my answer to your question will be in an update to the docs.

## License

MIT License

Copyright 2020 Rosa Richter

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
