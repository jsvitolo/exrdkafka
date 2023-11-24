defmodule Exrdkafka do
  @moduledoc """
  Elixir version of the Erlang erlkaf module.
  """

  require Logger

  alias Exrdkafka.CacheClient
  alias Exrdkafka.Config
  alias Exrdkafka.ErrorConverter
  alias Exrdkafka.Manager
  alias Exrdkafka.Producer
  alias Exrdkafka.Utils

  @type client_id :: atom()
  @type client_option :: any()
  @type topic_option :: any()
  @type topic :: any()
  @type key :: any()
  @type value :: any()
  @type headers :: any()
  @type partition :: any()

  def start(), do: start(:temporary)

  def start(type) do
    case Application.ensure_all_started(:exrdkafka, type) do
      {:ok, _} -> :ok
      other -> other
    end
  end

  def stop(), do: Application.stop(:exrdkafka)

  def create_producer(client_id, client_config) do
    global_client_opts = Utils.get_env(:global_client_options, [])
    config = Utils.append_props(client_config, global_client_opts)

    case Config.convert_kafka_config(config) do
      {:ok, exrdkafka_config, librdkafka_config} ->
        Manager.start_producer(client_id, exrdkafka_config, librdkafka_config)

      error ->
        error
    end
  end

  def create_consumer_group(client_id, group_id, topics, client_config0, default_topics_config) do
    global_client_opts = Utils.get_env(:global_client_options, [])
    client_config = Utils.append_props(client_config0, global_client_opts)

    Manager.start_consumer_group(
      client_id,
      group_id,
      topics,
      client_config,
      default_topics_config
    )
  end

  def stop_client(client_id), do: Manager.stop_client(client_id)

  def get_stats(client_id) do
    case CacheClient.get(client_id) do
      {:ok, _client_ref, client_pid} -> Utils.safe_call(client_pid, :get_stats)
      _ -> {:error, :err_undefined_client}
    end
  end

  def create_topic(client_id, topic_name), do: create_topic(client_id, topic_name, [])

  def create_topic(client_id, topic_name, topic_config) do
    case CacheClient.get(client_id) do
      {:ok, client_ref, _client_pid} ->
        case Config.convert_topic_config(topic_config) do
          {:ok, _erlkaf_config, librdkafka_config} ->
            Manager.create_topic(client_ref, topic_name, librdkafka_config)

          error ->
            error
        end

      _ ->
        {:error, :err_undefined_client}
    end
  end

  def get_metadata(client_id) do
    case CacheClient.get(client_id) do
      {:ok, client_ref, _client_pid} -> ExrdkafkaNif.get_metadata(client_ref)
      :undefined -> {:error, :err_undefined_client}
      error -> error
    end
  end

  def produce(client_id, topic_name, key, value),
    do: produce(client_id, topic_name, -1, key, value, :undefined, 0)

  def produce(client_id, topic_name, key, value, headers),
    do: produce(client_id, topic_name, -1, key, value, headers, 0)

  def produce(client_id, topic_name, partition, key, value, headers0),
    do: produce(client_id, topic_name, partition, key, value, headers0, 0)

  def produce(client_id, topic_name, partition, key, value, headers0, timestamp) do
    case CacheClient.get(client_id) do
      {:ok, client_ref, client_pid} ->
        headers = to_headers(headers0)

        case ExrdkafkaNif.produce(
               client_ref,
               topic_name,
               partition,
               key,
               value,
               headers,
               timestamp
             ) do
          :ok ->
            :ok

          {:error, :rd_kafka_resp_err_queue_full} ->
            case Producer.queue_event(
                   client_pid,
                   topic_name,
                   partition,
                   key,
                   value,
                   headers,
                   timestamp
                 ) do
              :ok ->
                :ok

              :drop_records ->
                Logger.warn("message: ~p dropped", [{topic_name, partition, key, value, headers}])
                :ok

              :block_calling_process ->
                produce_blocking(
                  client_ref,
                  topic_name,
                  partition,
                  key,
                  value,
                  headers,
                  timestamp
                )

              error ->
                error
            end

          error ->
            error
        end

      :undefined ->
        {:error, :err_undefined_client}

      error ->
        error
    end
  end

  def produce_sync(client_id, topic_name, partition, key, value, headers0, timestamp) do
    case CacheClient.get(client_id) do
      {:ok, client_ref, _client_pid} ->
        headers = to_headers(headers0)

        case ExrdkafkaNif.produce_sync(
               client_ref,
               topic_name,
               partition,
               key,
               value,
               headers,
               timestamp
             ) do
          :ok ->
            :ok

          error ->
            error
        end

      :undefined ->
        {:error, :err_undefined_client}

      error ->
        error
    end
  end

  def get_readable_error(error), do: ErrorConverter.get_readable_error(error)

  defp produce_blocking(client_ref, topic_name, partition, key, value, headers, timestamp) do
    case ExrdkafkaNif.produce(client_ref, topic_name, partition, key, value, headers, timestamp) do
      :ok ->
        :ok

      {:error, :rd_kafka_resp_err_queue_full} ->
        :timer.sleep(100)
        produce_blocking(client_ref, topic_name, partition, key, value, headers, timestamp)

      error ->
        error
    end
  end

  defp to_headers(:undefined), do: :undefined

  defp to_headers(headers) when is_list(headers) do
    Enum.map(headers, fn
      {k, v} = r when is_binary(k) and is_binary(v) -> r
      {k, v} -> {Utils.to_binary(k), Utils.to_binary(v)}
    end)
  end

  defp to_headers(v) when is_map(v), do: to_headers(Map.to_list(v))
end
