defmodule Exrdkafka.ConsumerGroup do
  use GenServer

  defstruct [
    :client_id,
    :client_ref,
    :topics_settings,
    :active_topics_map,
    :stats_cb,
    :stats
  ]

  alias Exrdkafka.CacheClient
  alias Exrdkafka.Utils

  require Logger

  def start_link(
        client_id,
        group_id,
        topics,
        ek_client_config,
        rdk_client_config,
        ek_topic_config,
        rdk_topic_config
      ) do
    GenServer.start_link(__MODULE__, [
      client_id,
      group_id,
      topics,
      ek_client_config,
      rdk_client_config,
      ek_topic_config,
      rdk_topic_config
    ])
  end

  def init([
        client_id,
        group_id,
        topics,
        ek_client_config,
        rdk_client_config,
        _ek_topic_config,
        rdk_topic_config
      ]) do
    Process.flag(:trap_exit, true)

    topics_names = Enum.map(topics, fn {k, _} -> k end)

    case ExrdkafkaNif.consumer_new(group_id, topics_names, rdk_client_config, rdk_topic_config) do
      {:ok, client_ref} ->
        :ok = CacheClient.set(client_id, :undefined, self())

        {:ok,
         %__MODULE__{
           client_id: client_id,
           client_ref: client_ref,
           topics_settings: Map.new(topics),
           active_topics_map: %{},
           stats_cb: Keyword.get(ek_client_config, :stats_callback)
         }}

      error ->
        {:stop, error}
    end
  end

  def handle_call(:get_stats, _from, %{stats: stats} = state), do: {:reply, {:ok, stats}, state}
  def handle_call(_request, _from, state), do: {:reply, :ok, state}
  def handle_cast(_request, state), do: {:noreply, state}

  def handle_info({:stats, stats0}, %{stats_cb: stats_cb, client_id: client_id} = state) do
    stats = Jason.decode(stats0)

    try do
      Utils.call_stats_callback(stats_cb, client_id, stats)
    rescue
      error ->
        Logger.error(
          "#{inspect(stats_cb)}:stats_callback client_id: #{inspect(client_id)} error: #{inspect(error)}"
        )
    end

    {:noreply, %{state | stats: stats}}
  end

  def handle_info(
        {:assign_partitions, partitions},
        %{
          client_ref: client_ref,
          topics_settings: topics_settings_map,
          active_topics_map: active_topics_map
        } = state
      ) do
    Logger.info("assign partitions: #{inspect(partitions)}")

    part_fun = fn {topic_name, partition, offset, queue_ref}, tmap ->
      {:ok, pid} =
        Exrdkafka.Consumer.start_link(
          client_ref,
          topic_name,
          partition,
          offset,
          queue_ref,
          Map.get(topics_settings_map, topic_name)
        )

      Map.put(tmap, {topic_name, partition}, {pid, queue_ref})
    end

    {:noreply, %{state | active_topics_map: Enum.reduce(partitions, active_topics_map, part_fun)}}
  end

  def handle_info(
        {:revoke_partitions, partitions},
        %{client_ref: client_ref, active_topics_map: active_topics_map} = state
      ) do
    Logger.info("revoke partitions: #{inspect(partitions)}")
    pid_queue_pairs = get_pid_queue_pairs(active_topics_map, partitions)
    stop_consumers(pid_queue_pairs)
    Logger.info("all existing consumers stopped for partitions: #{inspect(partitions)}")
    :ok = ExrdkafkaNif.consumer_partition_revoke_completed(client_ref)
    {:noreply, %{state | active_topics_map: %{}}}
  end

  def handle_info({:EXIT, from_pid, reason}, %{active_topics_map: active_topics} = state)
      when reason != :normal do
    case map_size(active_topics) do
      0 ->
        Logger.warning(
          "consumer #{inspect(from_pid)} died with reason: #{inspect(reason)}. no active topic (ignore message) ..."
        )

        {:noreply, state}

      _ ->
        Logger.warning(
          "consumer #{inspect(from_pid)} died with reason: #{inspect(reason)}. restart consumer group ..."
        )

        {:stop, {:error, reason}, state}
    end
  end

  def handle_info(_info, state), do: {:noreply, state}

  def terminate(_reason, %{
        active_topics_map: topics_map,
        client_ref: client_ref,
        client_id: client_id
      }) do
    stop_consumers(Map.values(topics_map))
    :ok = ExrdkafkaNif.consumer_cleanup(client_ref)

    Logger.info("wait for consumer client #{inspect(client_id)} to stop...")

    receive do
      :client_stopped ->
        Logger.info("client #{inspect(client_id)} stopped")
    after
      180_000 ->
        Logger.error("wait for client #{inspect(client_id)} stop timeout")
    end
  end

  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  defp get_pid_queue_pairs(topics_map, partitions) do
    Enum.map(partitions, &Map.get(topics_map, &1))
  end

  defp stop_consumers(pid_queue_pairs) do
    Enum.each(pid_queue_pairs, fn {pid, queue_ref} ->
      Exrdkafka.Consumer.stop(pid)
      :ok = ExrdkafkaNif.consumer_queue_cleanup(queue_ref)
    end)
  end
end
