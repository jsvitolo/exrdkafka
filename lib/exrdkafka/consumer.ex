defmodule Exrdkafka.Consumer do
  use GenServer

  @default_poll_idle_ms 1000
  @default_batch_size 100

  require Logger

  def start_link(client_ref, topic_name, partition, offset, queue_ref, topic_settings) do
    GenServer.start_link(
      __MODULE__,
      [client_ref, topic_name, partition, offset, queue_ref, topic_settings],
      []
    )
  end

  def stop(pid) do
    if Process.alive?(pid) do
      tag = make_ref()
      send(pid, {:stop, self(), tag})

      receive do
        {:stopped, ^tag} -> :ok
      after
        5000 -> Process.exit(pid, :kill)
      end
    else
      {:error, :not_alive}
    end
  end

  def init([client_ref, topic_name, partition, offset, queue_ref, topic_settings]) do
    Logger.info("start consumer for: #{topic_name} partition: #{partition} offset: #{offset}")

    cb_module = Keyword.get(topic_settings, :callback_module)
    cb_args = Keyword.get(topic_settings, :callback_args, [])
    dispatch_mode = Keyword.get(topic_settings, :dispatch_mode, :one_by_one)
    poll_idle_ms = Keyword.get(topic_settings, :poll_idle_ms, @default_poll_idle_ms)

    case cb_module.init(topic_name, partition, offset, cb_args) do
      {:ok, cb_state} ->
        schedule_poll(0)

        {dp_mode, poll_batch_size} = dispatch_mode_parse(dispatch_mode)

        {:ok,
         %{
           client_ref: client_ref,
           topic_name: topic_name,
           partition: partition,
           queue_ref: queue_ref,
           cb_module: cb_module,
           cb_state: cb_state,
           poll_batch_size: poll_batch_size,
           poll_idle_ms: poll_idle_ms,
           dispatch_mode: dp_mode,
           messages: [],
           last_offset: -1
         }}

      error ->
        Logger.error(
          "#{inspect(cb_module)}:init for topic: #{topic_name} failed with: #{inspect(error)}"
        )

        {:stop, error}
    end
  end

  def handle_call(request, _from, state) do
    Logger.error("handle_call unexpected message: #{inspect(request)}")
    {:reply, :ok, state}
  end

  def handle_cast(request, state) do
    Logger.error("handle_cast unexpected message: #{inspect(request)}")
    {:noreply, state}
  end

  def handle_info(
        :poll_events,
        %{queue_ref: queue, poll_batch_size: poll_batch_size, poll_idle_ms: poll_idle_ms} = state
      ) do
    case ExrdkafkaNif.consumer_queue_poll(queue, poll_batch_size) do
      {:ok, events, last_offset} ->
        case events do
          [] ->
            schedule_poll(poll_idle_ms)
            {:noreply, state}

          _ ->
            schedule_message_process(0)
            {:noreply, %{state | messages: events, last_offset: last_offset}}
        end

      error ->
        Logger.info("#{__MODULE__} poll events error: #{inspect(error)}")
        throw({:error, error})
    end
  end

  def handle_info(
        :process_messages,
        %{
          messages: msgs,
          dispatch_mode: dispatch_mode,
          client_ref: client_ref,
          cb_module: cb_module,
          cb_state: cb_state
        } = state
      ) do
    case process_events(
           dispatch_mode,
           msgs,
           batch_offset(dispatch_mode, state),
           client_ref,
           cb_module,
           cb_state
         ) do
      {:ok, new_cb_state} ->
        schedule_poll(0)
        {:noreply, %{state | messages: [], last_offset: -1, cb_state: new_cb_state}}

      {:stop, from, tag} ->
        handle_stop(from, tag, state)
        {:stop, :normal, state}

      error ->
        Logger.error("unexpected response: #{inspect(error)}")
        {:stop, error, state}
    end
  end

  def handle_info({:stop, from, tag}, state) do
    handle_stop(from, tag, state)
    {:stop, :normal, state}
  end

  def handle_info(info, state) do
    Logger.error("handle_info unexpected message: #{inspect(info)}")
    {:noreply, state}
  end

  def terminate(_reason, _state), do: :ok

  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  # internals
  defp batch_offset(:batch, %{topic_name: t, partition: p, last_offset: o}), do: {t, p, o}
  defp batch_offset(_, _), do: nil

  defp dispatch_mode_parse(:one_by_one), do: {:one_by_one, @default_batch_size}
  defp dispatch_mode_parse({:batch, max_batch_size}), do: {:batch, max_batch_size}

  defp schedule_poll(timeout), do: Process.send_after(self(), :poll_events, timeout)

  defp schedule_message_process(timeout),
    do: Process.send_after(self(), :process_messages, timeout)

  defp commit_offset(
         client_ref,
         {:exrdkafka_msg, topic, partition, offset, _key, _msg, _headers, _times}
       ) do
    ExrdkafkaNif.consumer_offset_store(client_ref, topic, partition, offset)
  end

  defp process_events(:one_by_one, msgs, _last_batch_offset, client_ref, cb_module, cb_state) do
    process_events_one_by_one(msgs, client_ref, 0, cb_module, cb_state)
  end

  defp process_events(:batch, msgs, last_batch_offset, client_ref, cb_module, cb_state) do
    process_events_batch(msgs, last_batch_offset, client_ref, 0, cb_module, cb_state)
  end

  defp process_events_batch(msgs, last_batch_offset, client_ref, backoff, cb_module, cb_state) do
    case cb_module.handle_message(msgs, cb_state) do
      {:ok, new_cb_state} ->
        {topic, partition, offset} = last_batch_offset
        :ok = ExrdkafkaNif.consumer_offset_store(client_ref, topic, partition, offset)
        {:ok, new_cb_state}

      {:error, reason, new_cb_state} ->
        Logger.error("#{inspect(cb_module)}:handle_message for batch error: #{inspect(reason)}")

        handle_backoff_or_stop(
          msgs,
          last_batch_offset,
          client_ref,
          backoff,
          cb_module,
          new_cb_state
        )

      error ->
        Logger.error("#{inspect(cb_module)}:handle_message for batch error: #{inspect(error)}")
        handle_backoff_or_stop(msgs, last_batch_offset, client_ref, backoff, cb_module, cb_state)
    end
  end

  defp handle_backoff_or_stop(msgs, last_batch_offset, client_ref, backoff, cb_module, cb_state) do
    case recv_stop() do
      false ->
        process_events_batch(
          msgs,
          last_batch_offset,
          client_ref,
          exponential_backoff(backoff),
          cb_module,
          cb_state
        )

      stop_msg ->
        stop_msg
    end
  end

  defp process_events_one_by_one([h | t] = msgs, client_ref, backoff, cb_module, cb_state) do
    case recv_stop() do
      false -> handle_message(h, msgs, t, client_ref, backoff, cb_module, cb_state)
      stop_msg -> stop_msg
    end
  end

  defp process_events_one_by_one([], _client_ref, _backoff, _cb_module, cb_state),
    do: {:ok, cb_state}

  defp handle_message(h, msgs, t, client_ref, backoff, cb_module, cb_state) do
    case cb_module.handle_message(h, cb_state) do
      {:ok, new_cb_state} ->
        :ok = commit_offset(client_ref, h)
        process_events_one_by_one(t, client_ref, 0, cb_module, new_cb_state)

      {:error, reason, new_cb_state} ->
        Logger.error(
          "#{inspect(cb_module)}:handle_message for: #{inspect(h)} error: #{inspect(reason)}"
        )

        process_events_one_by_one(
          msgs,
          client_ref,
          exponential_backoff(backoff),
          cb_module,
          new_cb_state
        )

      error ->
        Logger.error(
          "#{inspect(cb_module)}:handle_message for: #{inspect(h)} error: #{inspect(error)}"
        )

        process_events_one_by_one(
          msgs,
          client_ref,
          exponential_backoff(backoff),
          cb_module,
          cb_state
        )
    end
  end

  defp recv_stop() do
    receive do
      {_stop, _from, _tag} = msg -> msg
    after
      0 -> false
    end
  end

  defp handle_stop(from, tag, %{topic_name: topic_name, partition: partition}) do
    Logger.info("stop consumer for: #{inspect(topic_name)} partition: #{inspect(partition)}")
    send(from, {:stopped, tag})
  end

  defp exponential_backoff(0), do: 500
  defp exponential_backoff(4000), do: :timer.sleep(4000) && 4000
  defp exponential_backoff(backoff), do: :timer.sleep(backoff) && backoff * 2
end
