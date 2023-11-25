defmodule Exrdkafka.ClientSupervisor do
  @moduledoc """
  Documentation for `Exrdkafka.ClientSupervisor`.
  """

  use Supervisor

  alias Exrdkafka.Manager

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      {Manager, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def add_client(client_id, module, args) do
    child_spec = %{
      id: client_id,
      start: {module, :start_link, args},
      restart: :transient,
      shutdown: :infinity,
      type: :worker
    }

    Supervisor.start_child(__MODULE__, child_spec)
  end

  def remove_client(client_id) do
    case Supervisor.terminate_child(__MODULE__, client_id) do
      :ok ->
        Supervisor.delete_child(__MODULE__, client_id)

      error ->
        error
    end
  end
end
