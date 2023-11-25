defmodule Exrdkafka.MixProject do
  use Mix.Project

  def project do
    [
      app: :exrdkafka,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
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
      {:esq, "~> 2.0"},
      {:jason, "~> 1.4"}
    ]
  end

  defp aliases do
    [
      # Define a new "compile.c_src" alias
      "compile.c_src": ["cmd make compile_nif"],
      # Add "compile.c_src" to the "compile" alias
      compile: ["compile --warnings-as-errors", "recompile_nif"],
      # Add "cmd make clean_nif" to the "clean" alias
      recompile_nif: ["cmd make clean_nif", "cmd make compile_nif"],
      clean: ["clean", "cmd make clean_nif"]
    ]
  end
end
