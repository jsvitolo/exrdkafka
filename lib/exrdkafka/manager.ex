defmodule Exrdkafka.Manager do
  @moduledoc """
  Documentation for `Exrdkafka.Manager`.
  """
  use GenServer

  alias Exrdkafka.CacheClient
  alias Exrdkafka.Utils
  alias Exrdkafka.Producer
  alias Exrdkafka.ClientSupervisor

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_producer(client_id, exrdkafka_config, librdkafka_config) do
    GenServer.call(__MODULE__, {:start_producer, client_id, exrdkafka_config, librdkafka_config})
  end

  def start_consumer_group(client_id, group_id, topics, client_config, default_topics_config) do
    GenServer.call(
      __MODULE__,
      {:start_consumer_group, client_id, group_id, topics, client_config, default_topics_config}
    )
  end

  def stop_client(client_id) do
    GenServer.call(__MODULE__, {:stop_client, client_id})
  end

  def create_topic(client_ref, topic_name, topic_config) do
    GenServer.call(__MODULE__, {:create_topic, client_ref, topic_name, topic_config})
  end

  def init([]) do
    {:ok, %{}}
  end

  def handle_call({:create_topic, client_ref, topic_name, topic_config}, _from, state) do
    {:reply, ExrdkafkaNif.producer_topic_new(client_ref, topic_name, topic_config), state}
  end

  def handle_call({:start_producer, client_id, exrdkafka_config, librdkafka_config}, _from, state) do
    case internal_start_producer(client_id, exrdkafka_config, librdkafka_config) do
      {:ok, _pid} ->
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(
        {:start_consumer_group, client_id, group_id, topics, client_config,
         default_topics_config},
        _from,
        state
      ) do
    case internal_start_consumer(
           client_id,
           group_id,
           topics,
           client_config,
           default_topics_config
         ) do
      {:ok, _pid} ->
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:stop_client, client_id}, _from, state) do
    {:reply, internal_stop_client(client_id), state}
  end

  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_request, state) do
    {:noreply, state}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  # Implement the following functions according to your needs
  defp internal_start_producer(client_id, exrdkafka_config, librdkafka_config) do
    case CacheClient.get(client_id) do
      :undefined ->
        delivery_report_callback = Utils.lookup(:delivery_report_callback, exrdkafka_config)
        has_dr_callback = delivery_report_callback != :undefined

        case ExrdkafkaNif.producer_new(has_dr_callback, librdkafka_config) do
          {:ok, producer_ref} ->
            ClientSupervisor.add_client(client_id, Producer, [
              client_id,
              delivery_report_callback,
              exrdkafka_config,
              producer_ref
            ])

          error ->
            error
        end

      {:ok, _, _} ->
        {:error, :err_already_existing_client}
    end
  end

  defp internal_start_consumer(_, _, _, _, _), do: {:error, :not_implemented}
  defp internal_stop_client(_), do: {:error, :not_implemented}
end
