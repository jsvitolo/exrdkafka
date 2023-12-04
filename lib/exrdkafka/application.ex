defmodule Exrdkafka.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Exrdkafka.CacheClient

  @impl true
  def start(_type, _args) do
    :ok = CacheClient.create()

    children = [
      {Exrdkafka.ClientSupervisor, []},
      {Exrdkafka.Clients, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Exrdkafka.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
