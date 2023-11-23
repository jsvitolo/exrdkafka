defmodule Exrdkafka.Producer do
  @moduledoc """
  Documentation for `ExrdkafkaProducer`.
  """

  use GenServer

  alias Exrdkafka.CacheClient
  alias Exrdkafka.LocalQueue
  alias Exrdkafka.Utils

  @max_queue_process_msg 5000

  require Logger

  def start_link(client_id, dr_callback, erlkaf_config, producer_ref) do
    GenServer.start_link(__MODULE__, [client_id, dr_callback, erlkaf_config, producer_ref], [])
  end

  def queue_event(pid, topic_name, partition, key, value, headers, timestamp) do
    Utils.safe_call(
      pid,
      {:queue_event, topic_name, partition, key, value, headers, timestamp}
    )
  end

  def init([client_id, dr_callback, erlkaf_config, producer_ref]) do
    pid = self()

    overflow_strategy =
      Utils.lookup(:queue_buffering_overflow_strategy, erlkaf_config, :local_disk_queue)

    stats_callback = Utils.lookup(:stats_callback, erlkaf_config)
    :ok = ExrdkafkaNif.producer_set_owner(producer_ref, pid)
    :ok = CacheClient.set(client_id, producer_ref, pid)
    {:ok, queue} = LocalQueue.new(client_id)
    Process.flag(:trap_exit, true)

    case overflow_strategy do
      :local_disk_queue -> schedule_consume_queue(0)
      _ -> :ok
    end

    {:ok,
     %{
       client_id: client_id,
       ref: producer_ref,
       callback: dr_callback,
       stats_cb: stats_callback,
       overflow_method: overflow_strategy,
       pqueue: queue,
       pqueue_sch: true
     }}
  end

  def handle_call(
        {:queue_event, topic_name, partition, key, value, headers, timestamp},
        _from,
        state
      ) do
    case state.overflow_method do
      :local_disk_queue ->
        schedule_consume_queue(state.pqueue_sch, 1000)

        :ok =
          LocalQueue.enq(
            state.pqueue,
            topic_name,
            partition,
            key,
            value,
            headers,
            timestamp
          )

        {:reply, :ok, %{state | pqueue_sch: true}}

      _ ->
        {:reply, state.overflow_method, state}
    end
  end

  def handle_call(:get_stats, _from, state), do: {:reply, {:ok, state.stats}, state}

  def handle_call(_request, _from, state), do: {:reply, :ok, state}

  def handle_cast(_request, state), do: {:noreply, state}

  def handle_info(:consume_queue, state) do
    case consume_queue(state.ref, state.pqueue, @max_queue_process_msg) do
      :completed ->
        {:noreply, %{state | pqueue_sch: false}}

      :ok ->
        schedule_consume_queue(1000)
        {:noreply, %{state | pqueue_sch: true}}
    end
  end

  def handle_info({:delivery_report, delivery_status, message}, %{callback: callback} = state) do
    call_callback(callback, delivery_status, message)

    {:noreply, state}
  end

  def handle_info({:stats, stats}, state) do
    {:noreply, %{state | stats: stats}}
  end

  def handle_info(info, state) do
    Logger.error("received unknown message: #{inspect(info)}")

    {:noreply, state}
  end

  def terminate(reason, %{client_id: client_id, ref: client_ref, pqueue: queue}) do
    LocalQueue.free(queue)

    case reason do
      :shutdown ->
        :ok = ExrdkafkaNif.producer_cleanup(client_ref)
        Logger.info("wait for producer client #{inspect(client_id)} to stop...")

        receive do
          :client_stopped -> Logger.info("producer client #{inspect(client_id)} stopped")
        end

      _ ->
        :ok
    end
  end

  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  defp call_callback(:undefined, _delivery_status, _message), do: :ok

  defp call_callback(callback, delivery_status, message) when is_function(callback, 2),
    do: callback.(delivery_status, message)

  defp call_callback(callback, delivery_status, message),
    do: callback.delivery_report(delivery_status, message)

  defp schedule_consume_queue(false, timeout),
    do: Process.send_after(self(), :consume_queue, timeout)

  defp schedule_consume_queue(_, _), do: :ok

  defp schedule_consume_queue(timeout), do: Process.send_after(self(), :consume_queue, timeout)

  defp consume_queue(_client_ref, _q, 0) do
    log_completed(0)
    :ok
  end

  defp consume_queue(client_ref, q, n) do
    case LocalQueue.head(q) do
      :undefined ->
        log_completed(n)
        :completed

      %{payload: msg} ->
        {topic_name, partition, key, value, headers, timestamp} = decode_queued_message(msg)

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
            [%{payload: _msg}] = LocalQueue.deq(q)
            consume_queue(client_ref, q, n - 1)

          {:error, :rd_kafka_resp_err_queue_full} ->
            log_completed(n)
            :ok

          error ->
            Logger.error("message #{inspect(msg)} skipped because of error: #{inspect(error)}")
            [%{payload: _msg}] = LocalQueue.deq(q)
            consume_queue(client_ref, q, n - 1)
        end
    end
  end

  defp log_completed(n) do
    if n != @max_queue_process_msg do
      Logger.info("pushed #{inspect(@max_queue_process_msg - n)} events from local queue cache")
    end
  end

  defp decode_queued_message({topic_name, partition, key, value, headers}) do
    {topic_name, partition, key, value, headers, 0}
  end

  defp decode_queued_message(r), do: r
end
