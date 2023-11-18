defmodule ExrdkafkaNif do
  @on_load :load_nif

  def load_nif do
    path = :filename.join(:code.priv_dir(:exrdkafka), 'exrdkafka_nif')

    :erlang.load_nif(path, 0)
  end

  def set_log_process(_pid), do: raise_not_loaded(__ENV__.line)

  def producer_new(_has_dr_callback, _config), do: raise_not_loaded(__ENV__.line)

  def producer_cleanup(_client_ref), do: raise_not_loaded(__ENV__.line)

  def producer_set_owner(_client_ref, _pid), do: raise_not_loaded(__ENV__.line)

  def producer_topic_new(_client_ref, _topic_name, _topic_config),
    do: raise_not_loaded(__ENV__.line)

  def produce(_client_ref, _topic_ref, _partition, _key, _value, _headers, _timestamp) do
    raise_not_loaded(__ENV__.line)
  end

  def get_metadata(_client_ref), do: raise_not_loaded(__ENV__.line)

  def consumer_new(_group_id, _topics, _client_config, _topics_config),
    do: raise_not_loaded(__ENV__.line)

  def consumer_partition_revoke_completed(_client_ref), do: raise_not_loaded(__ENV__.line)

  def consumer_queue_poll(_queue, _batch_size), do: raise_not_loaded(__ENV__.line)

  def consumer_queue_cleanup(_queue), do: raise_not_loaded(__ENV__.line)

  def consumer_offset_store(_client_ref, _topic_name, _partition, _offset),
    do: raise_not_loaded(__ENV__.line)

  def consumer_cleanup(_client_ref), do: raise_not_loaded(__ENV__.line)

  defp raise_not_loaded(line) do
    raise "NIF not loaded: #{__MODULE__}, line: #{line}"
  end
end
