defmodule Exrdkafka.MixProject do
  use Mix.Project

  def project do
    [
      app: :exrdkafka,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      # compilers: [:c_src] ++ Mix.compilers(),
      aliases: aliases(),
      deps: deps()
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
      {:esq, "~> 2.0"}
    ]
  end

  defp aliases do
    [
      # Define a new "compile.c_src" alias
      "compile.c_src": ["cmd make compile_nif"],
      # compile: ["compile --warnings-as-errors", "compile.c_src"], # Add "compile.c_src" to the "compile" alias
      # Add "cmd make clean_nif" to the "clean" alias
      clean: ["clean", "cmd make clean_nif"]
    ]
  end
end
