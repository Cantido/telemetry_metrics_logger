defmodule TelemetryMetricsLogger do
  @moduledoc """
  A reporter that prints events to the `Logger`.

  This module aggregates and prints metrics information at a configurable frequency.

  For example, imagine the given metrics:

      metrics = [
        last_value("vm.memory.binary", unit: :byte),
        counter("vm.memory.total"),
        summary("phoenix.endpoint.stop.duration", unit: {:native, :millisecond})
      ]

  A this reporter can be started as a child of your supervision tree like this:

      {TelemetryMetricsLogger, metrics: metrics, interval: 60}

  Then, every sixty seconds, you will see a report like this:

  ```log
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
  """

  use GenServer
  require Logger

  def start_link(opts) do
    metrics =
      opts[:metrics] ||
        raise ArgumentError, "the :metrics option is required by #{inspect(__MODULE__)}"

    reporter_options = Keyword.get(opts, :reporter_options, [])

    log_level = reporter_options |> Keyword.get(:log_level, :info)
    reporting_interval = reporter_options |> Keyword.get(:interval, 60)

    GenServer.start_link(__MODULE__, {metrics, log_level, reporting_interval}, name: __MODULE__)
  end

  def handle_event(event_name, measurements, metadata, _config) do
    GenServer.cast(__MODULE__, {:handle_event, event_name, measurements, metadata})
  end

  @impl true
  def init({metrics, log_level, reporting_interval}) do
    Process.flag(:trap_exit, true)
    groups = Enum.group_by(metrics, & &1.event_name)

    for {event, _metrics} <- groups do
      id = {__MODULE__, event, self()}
      :telemetry.attach(id, event, &handle_event/4, [])
    end

    Process.send_after(self(), :report, reporting_interval * 1_000)

    {
      :ok,
      %{
        metric_definitions: groups,
        reporting_interval: reporting_interval,
        log_level: log_level,
        report: %{}
      }
    }
  end

  @impl true
  def terminate(_, state) do
    events =
      state.metric_definitions
      |> Map.keys()

    for event <- events do
      :telemetry.detach({__MODULE__, event, self()})
    end

    :ok
  end

  @impl true
  def handle_cast({:handle_event, event_name, measurements, metadata}, state) do
    metric_defs_for_event = state.metric_definitions[event_name]

    report =
      metric_defs_for_event
      |> Enum.map(fn metric_def ->
        measurement = extract_measurement(metric_def, measurements, metadata)
        tags = extract_tags(metric_def, metadata)
        {metric_def, measurement, tags}
      end)
      |> Enum.filter(fn {mdef, _m, _tags} -> keep?(mdef, metadata) end)
      |> Enum.reduce(state.report, &update_report(event_name, &1, &2))

    {:noreply, %{state | report: report}}
  end

  defp update_report(event_name, {metric_def, measurement, tags}, report) do
    Map.update(
      report,
      metric_def.name,
      new_metric_value(metric_def, measurement),
      &update_metric_value(metric_def, &1, measurement)
    )
  end

  defp new_metric_value(%Telemetry.Metrics.Counter{}, _measurement), do: %{counter: 1}
  defp new_metric_value(%Telemetry.Metrics.Distribution{}, measurement), do: %{distribution: [measurement]}
  defp new_metric_value(%Telemetry.Metrics.LastValue{}, measurement), do: %{last_value: measurement}
  defp new_metric_value(%Telemetry.Metrics.Sum{}, measurement), do: %{sum: measurement}
  defp new_metric_value(%Telemetry.Metrics.Summary{}, measurement), do: %{summary: [measurement]}

  defp update_metric_value(%Telemetry.Metrics.Counter{}, current_value, _measurement) do
    Map.update(current_value, :counter, 1, &(&1 + 1))
  end

  defp update_metric_value(%Telemetry.Metrics.Distribution{}, current_value, measurement) do
    Map.update(current_value, :distribution, [measurement], &[measurement | &1])
  end

  defp update_metric_value(%Telemetry.Metrics.LastValue{}, current_value, measurement) do
    Map.update(current_value, :last_value, measurement, measurement)
  end

  defp update_metric_value(%Telemetry.Metrics.Sum{}, current_value, measurement) do
    Map.update(current_value, :sum, measurement, &( &1 + measurement))
  end

  defp update_metric_value(%Telemetry.Metrics.Summary{}, current_value, measurement) do
    Map.update(current_value, :summary, [measurement], &[measurement | &1])
  end

  defp keep?(%{keep: nil}, _metadata), do: true
  defp keep?(metric, metadata), do: metric.keep.(metadata)

  defp extract_measurement(metric, measurements, metadata) do
    case metric.measurement do
      fun when is_function(fun, 2) -> fun.(measurements, metadata)
      fun when is_function(fun, 1) -> fun.(measurements)
      key -> measurements[key]
    end
  end

  defp extract_tags(metric, metadata) do
    tag_values = metric.tag_values.(metadata)
    Map.take(tag_values, metric.tags)
  end

  def handle_info(:report, state) do
    report = build_report(state, DateTime.utc_now())
    Logger.log(state.log_level, report)

    Process.send_after(self(), :report, state.reporting_interval * 1_000)
    {:noreply, %{state | report: %{}}}
  end

  @doc false
  def build_report(state, timestamp) do
    metric_def_groups = state.metric_definitions

    ["Telemetry report #{timestamp}:" |
    Enum.flat_map(metric_def_groups, fn {event, defs} ->
      measurement_groups = Enum.group_by(defs, &List.last(&1.name))

      ["  Event #{inspect event}" |
      Enum.flat_map(measurement_groups, fn {measurement_name, defs} ->
        ["    Measurement \"#{measurement_name}\"" |
        Enum.map(defs, fn def ->
          metric_report = Map.get(state.report, def.name, %{})
          metric_text(def, metric_report)
        end)]
      end)]
    end)]
    |> Enum.join("\n")
    |> String.trim_trailing()
  end

  defp metric_text(%Telemetry.Metrics.Counter{}, report) do
    counter = Map.get(report, :counter, 0)
    "      Counter: #{counter}"
  end

  defp metric_text(%Telemetry.Metrics.Distribution{} = def, report) do
    distribution = Map.get(report, :distribution, [])

    if Enum.empty(distribution) do
      "      Distribution: No data for distribution!"
    else
      avg = Enum.sum(report.distribution) / Enum.count(report.distribution)
      """
            Distribution:
              mean: #{avg} #{unit_to_string def.unit}
      """
    end
  end

  defp metric_text(%Telemetry.Metrics.LastValue{} = def, report) do
    if is_nil(report[:last_value]) do
      "      Last value: No data!"
    else
      "      Last value: #{report.last_value} #{unit_to_string def.unit}"
    end
  end

  defp metric_text(%Telemetry.Metrics.Sum{} = def, report) do
    sum = Map.get(report, :sum, 0)

    "      Sum: #{sum} #{unit_to_string def.unit}"
  end

  defp metric_text(%Telemetry.Metrics.Summary{} = def, report) do
    summary = Map.get(report, :summary, [])

    if Enum.empty?(summary) do
      "      Summary: No data for summary!"
    else
      avg = Enum.sum(summary) / Enum.count(summary)
      """
            Summary:
              Average: #{avg} #{unit_to_string def.unit}
              Max: #{Enum.max(summary)} #{unit_to_string def.unit}
              Min: #{Enum.min(summary)} #{unit_to_string def.unit}
      """ |> String.trim_trailing()
    end
  end

  defp unit_to_string(:unit), do: ""
  defp unit_to_string(:second), do: "s"
  defp unit_to_string(:millisecond), do: "ms"
  defp unit_to_string(:microsecond), do: "μs"
  defp unit_to_string(:nanosecond), do: "ns"
  defp unit_to_string(:byte), do: "B"
  defp unit_to_string(:kilobyte), do: "kB"
  defp unit_to_string(:megabyte), do: "MB"
end
