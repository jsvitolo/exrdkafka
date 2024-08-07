defmodule ExrdkafkaNif do
  @on_load :__on_load__

  def __on_load__ do
    # We refer to `:code.priv_dir` indirectly because at runtime, the `priv` dir
    # is not necessarily in the same path as `./priv` -- as an exercise,
    # try running it via `iex -S mix` and check the returned path!
    path = :filename.join(:code.priv_dir(:exrdkafka), "exrdkafka_nif")
    :erlang.load_nif(path, 0)
  end

  def set_log_process(_pid), do: :erlang.nif_error(:nif_library_not_loaded)

  def producer_new(_has_dr_callback, _config), do: :erlang.nif_error(:nif_library_not_loaded)

  def producer_cleanup(_client_ref), do: :erlang.nif_error(:nif_library_not_loaded)

  def producer_set_owner(_client_ref, _pid), do: :erlang.nif_error(:nif_library_not_loaded)

  def producer_topic_new(_client_ref, _topic_name, _topic_config),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def produce(_client_ref, _topic_ref, _partition, _key, _value, _headers, _timestamp) do
    :erlang.nif_error(:nif_library_not_loaded)
  end

  def produce_sync(_client_ref, _topic_ref, _partition, _key, _value, _headers, _timestamp) do
    :erlang.nif_error(:nif_library_not_loaded)
  end

  def produce_batch(_client_ref, _topic_ref, _messages) do
    :erlang.nif_error(:nif_library_not_loaded)
  end

  def get_metadata(_client_ref), do: :erlang.nif_error(:nif_library_not_loaded)
  def get_partitions_count(_client_ref, _topic_name), do: :erlang.nif_error(:nif_library_not_loaded)

  def consumer_new(_group_id, _topics, _client_config, _topics_config),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def consumer_partition_revoke_completed(_client_ref), do: :erlang.nif_error(:nif_library_not_loaded)

  def consumer_queue_poll(_queue, _batch_size), do: :erlang.nif_error(:nif_library_not_loaded)

  def consumer_queue_cleanup(_queue), do: :erlang.nif_error(:nif_library_not_loaded)

  def consumer_offset_store(_client_ref, _topic_name, _partition, _offset),
    do: :erlang.nif_error(:nif_library_not_loaded)

  def consumer_cleanup(_client_ref), do: :erlang.nif_error(:nif_library_not_loaded)
end
