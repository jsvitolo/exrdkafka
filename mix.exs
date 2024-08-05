defmodule Exrdkafka.MixProject do
  use Mix.Project

  def project do
    [
      app: :exrdkafka,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      artifacts: ["priv/exrdkafka_nif.so"]
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
      # Define a new alias "compile.c_src" to compile the NIF
      "compile.c_src": ["cmd make compile_nif"],
      # Adds "compile.c_src" to the "compile" alias
      compile: ["compile --warnings-as-errors", "compile.c_src"],
      # Define an alias "clean.c_src" to clean the NIF
      "clean.c_src": ["cmd make clean_nif"],
      # Adds "clean.c_src" to the "clean" alias
      clean: ["clean", "clean.c_src"]
    ]
  end
end
