defmodule Exrdkafka.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :exrdkafka,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Configuração do elixir_make
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_clean: ["clean"],
      make_targets: ["all"],
      make_cwd: ".",
      make_env: %{"MIX_ENV" => "#{Mix.env()}"},

      # Configuração para pré-compilação
      make_precompiler: {:nif, CCPrecompiler},
      make_precompiler_url: "https://github.com/jsvitolo/exrdkafka/releases/download/v#{@version}/@{artefact_filename}",
      make_precompiler_filename: "exrdkafka_nif",
      make_precompiler_priv_paths: ["exrdkafka_nif.*"],

      # Configuração do cc_precompiler
      cc_precompile: [
        compilers: %{
          {:unix, :linux} => %{
            "x86_64-linux-gnu" => "x86_64-linux-gnu-",
            "aarch64-linux-gnu" => "aarch64-linux-gnu-",
          },
          {:unix, :darwin} => %{
            "x86_64-apple-darwin" => {
              "gcc",
              "g++",
              "<%= cc %> -arch x86_64",
              "<%= cxx %> -arch x86_64"
            },
            "aarch64-apple-darwin" => {
              "gcc",
              "g++",
              "<%= cc %> -arch arm64",
              "<%= cxx %> -arch arm64"
            }
          },
          {:win32, :nt} => %{
            "x86_64-windows-msvc" => {"cl", "cl"}
          }
        }
      ]
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
      {:elixir_make, "~> 0.8", runtime: false},
      {:cc_precompiler, "~> 0.1.0", runtime: false, github: "cocoa-xu/cc_precompiler"}
    ]
  end
end
