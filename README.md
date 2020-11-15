# TelemetryMetricsLogger

A ['telemetry_metrics'](https://github.com/beam-telemetry/telemetry_metrics) reporter that prints to the `Logger`.

This is different from the built-in console reporter for two reasons:

1. This reporter prints to the logger, instead of standard output
2. This reporter calculates metrics and prints a periodic report, instead of printing every configured event immediately

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `telemetry_metrics_logger` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:telemetry_metrics_logger, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/telemetry_metrics_logger](https://hexdocs.pm/telemetry_metrics_logger).

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
