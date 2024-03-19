defmodule TelemetryMetricsLogger.MixProject do
  use Mix.Project

  def project do
    [
      app: :telemetry_metrics_logger,
      description: "A telemetry_metrics reporter that writes to the Logger",
      package: package(),
      docs: docs(),
      version: "0.1.1",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry_metrics, "~> 1.0"},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end

  def docs do
    [
      source_url: "https://github.com/Cantido/telemetry_metrics_logger"
    ]
  end

  defp package do
    [
      maintainers: ["Rosa Richter"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/Cantido/telemetry_metrics_logger"}
    ]
  end
end
