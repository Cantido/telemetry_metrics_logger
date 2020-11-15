defmodule TelemetryMetricsLoggerTest do
  use ExUnit.Case
  doctest TelemetryMetricsLogger
  require Logger

  test "builds report" do
    state = %{
      metric_definitions: %{
        [:http, :request, :stop] => [
          Telemetry.Metrics.counter("http.request.stop.duration", unit: {:native, :microsecond}),
          Telemetry.Metrics.sum("http.request.stop.duration", unit: {:native, :microsecond}),
          Telemetry.Metrics.last_value("http.request.stop.duration", unit: {:native, :microsecond}),
          Telemetry.Metrics.summary("http.request.stop.duration", unit: {:native, :microsecond}),
          Telemetry.Metrics.distribution("http.request.stop.duration", unit: {:native, :microsecond})
        ]
      },
      report: %{
        [:http, :request, :stop, :duration] => %{
          counter: 6,
          sum: 31415,
          last_value: 42,
          summary: [4, 8, 15, 16, 23, 42],
          distribution: [4, 8, 15, 16, 23, 42]
        }
      }
    }

    report = TelemetryMetricsLogger.build_report(state, ~U[2020-11-15 19:25:17.259000Z])
    Logger.info(report)

    assert report == """
    Telemetry report 2020-11-15 19:25:17.259000Z:
      Event [:http, :request, :stop]
        Measurement "duration"
          Counter: 6
          Sum: 31415 μs
          Last value: 42 μs
          Summary:
            Average: 18.0 μs
            Max: 42 μs
            Min: 4 μs
          Distribution:
            mean: 18.0 μs
    """ |> String.trim_trailing()
  end
end
