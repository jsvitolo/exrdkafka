defmodule Exrdkafka.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/jsvitolo/exrdkafka"

  def project do
    [
      app: :exrdkafka,
      version: @version,
      elixir: "~> 1.14",
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_precompiler: {:nif, CCPrecompiler},
      make_precompiler_url: "https://github.com/jsvitolo/exrdkafka/releases/download/v#{@version}/@{artefact_filename}",
      make_env: %{"MIX_ENV" => to_string(Mix.env())},
      make_clean: ["clean"],
      make_targets: ["all"],
      make_cwd: ".",
      make_error_message: "Error compiling NIF",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Exrdkafka.Application, []}
    ]
  end

  defp deps do
    [
      {:esq, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:elixir_make, "~> 0.8.4", runtime: false},
      {:cc_precompiler, "~> 0.1.0", runtime: false}
    ]
  end

  defp package do
    [
      files: ["lib", "c_src", "mix.exs", "README*", "LICENSE*", "Makefile", "build_deps.sh"],
      maintainers: ["Your Name"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
end
