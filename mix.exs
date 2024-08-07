defmodule Exrdkafka.MixProject do
  use Mix.Project

  def project do
    [
      app: :exrdkafka,
      version: "0.1.0",
      elixir: "~> 1.14",
      compilers: [:elixir_make | Mix.compilers()],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      make_targets: ["all"],
      make_clean: ["clean"],
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Exrdkafka.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:esq, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:elixir_make, "~> 0.8.4", runtime: false}
    ]
  end

  defp aliases do
    [
      compile: ["compile", &compile_nif/1],
      clean: ["clean", &clean_nif/1]
    ]
  end

  # defp erlc_options do
  #   [
  #     warnings_as_errors: true,
  #     warn_export_all: true
  #   ]
  # end

  defp compile_nif(_) do
    if match?({:unix, _}, :os.type()) do
      {_result, _} = System.cmd("make", ["compile_nif"], stderr_to_stdout: true)
    end
  end

  defp clean_nif(_) do
    if match?({:unix, _}, :os.type()) do
      {_result, _} = System.cmd("make", ["clean_nif"], stderr_to_stdout: true)
    end
  end
end
