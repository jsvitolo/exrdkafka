defmodule Exrdkafka.MixProject do
  use Mix.Project

  def project do
    [
      app: :exrdkafka,
      version: "0.1.0",
      elixir: "~> 1.14",
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_env: %{"MIX_ENV" => to_string(Mix.env())},
      make_clean: ["clean"],
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:elixir_make, "~> 0.8.4", runtime: false}
    ]
  end
end
