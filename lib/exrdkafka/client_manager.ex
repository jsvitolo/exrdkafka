defmodule Exrdkafka.ClientManager do
  @moduledoc """
  The `ClientManager` module provides a high-level API for managing Kafka
  clients in an Elixir application.

  This module encapsulates the logic for creating topics, starting and stopping
  producers and consumers, and other Kafka-related operations. It maintains an
  internal state that evolves over time based on these operations.

  Key functions include `create_topic`, `start_producer`, `start_consumer_group`,
  and `stop_client`, which are invoked through synchronous `GenServer` calls.

  While the module is equipped to handle asynchronous messages via `handle_cast`,
  the current implementation treats such messages as unexpected.

  Under the hood, `ClientManager` leverages the power of NIFs to interact
  with the `librdkafka` C library. This ensures efficient communication with
  Kafka while providing a friendly Elixir API.
  """

  use GenServer

  alias Exrdkafka.CacheClient
  alias Exrdkafka.ClientSupervisor
  alias Exrdkafka.Config
  alias Exrdkafka.Producer
  alias Exrdkafka.Utils

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec start_producer(atom(), map(), map()) :: :ok | {:error, any()}
  def start_producer(client_id, exrdkafka_config, librdkafka_config) do
    GenServer.call(__MODULE__, {:start_producer, client_id, exrdkafka_config, librdkafka_config})
  end

  @spec start_consumer_group(atom(), binary(), list(), map(), map()) :: :ok | {:error, any()}
  def start_consumer_group(client_id, group_id, topics, client_config, default_topics_config) do
    GenServer.call(
      __MODULE__,
      {:start_consumer_group, client_id, group_id, topics, client_config, default_topics_config}
    )
  end

  @spec stop_client(atom()) :: :ok | {:error, any()}
  def stop_client(client_id) do
    GenServer.call(__MODULE__, {:stop_client, client_id})
  end

  @spec create_topic(atom(), binary(), map()) :: :ok | {:error, any()}
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

  defp internal_start_producer(client_id, exrdkafka_config, librdkafka_config) do
    case CacheClient.get(client_id) do
      :undefined -> start_new_producer(client_id, exrdkafka_config, librdkafka_config)
      {:ok, _, _} -> {:error, :err_already_existing_client}
    end
  end

  defp start_new_producer(client_id, exrdkafka_config, librdkafka_config) do
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
  end

  defp internal_start_consumer(client_id, group_id, topics, client_config, default_topics_config) do
    with :undefined <- CacheClient.get(client_id),
         :ok <- valid_consumer_topics(topics),
         {:ok, ek_client_config, rdk_client_config} <- Config.convert_kafka_config(client_config),
         {:ok, ek_topic_config, rdk_topic_config} <-
           Config.convert_topic_config(default_topics_config) do
      args = [
        client_id,
        group_id,
        topics,
        ek_client_config,
        rdk_client_config,
        ek_topic_config,
        rdk_topic_config
      ]

      ClientSupervisor.add_client(client_id, Exrdkafka.ConsumerGroup, args)
    else
      {:ok, _, _} -> {:error, :err_already_existing_client}
      error -> error
    end
  end

  defp valid_consumer_topics([]), do: :ok

  defp valid_consumer_topics([{k, v} | t]) when is_binary(k) and is_list(v) do
    mod = Utils.lookup(:callback_module, v)

    if mod != :undefined and is_atom(mod) do
      valid_consumer_topics(t)
    else
      {:error, {:invalid_topic, {k, v}}}
    end
  end

  defp valid_consumer_topics([h | _]), do: {:error, {:invalid_topic, h}}
  # defp internal_start_consumer(_, _, _, _, _), do: {:error, :not_implemented}
  defp internal_stop_client(_), do: {:error, :not_implemented}
end
