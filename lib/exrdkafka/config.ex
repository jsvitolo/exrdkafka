defmodule Exrdkafka.Config do
  @moduledoc """
  Documentation for `ExrdkafkaConfig`.
  """

  alias Exrdkafka.Utils

  def convert_topic_config(conf) do
    try do
      filter_topic_config(conf, [], [])
    catch
      _, reason -> reason
    end
  end

  def convert_kafka_config(conf) do
    try do
      filter_kafka_config(conf, [], [])
    catch
      _, reason -> reason
    end
  end

  defp filter_topic_config([{k, v} = h | t], exrdkafka_acc, rd_kafka_conf) do
    case is_exrdkafka_topic_config(k, v) do
      true ->
        filter_topic_config(t, [h | exrdkafka_acc], rd_kafka_conf)

      _ ->
        filter_topic_config(t, exrdkafka_acc, [to_librdkafka_topic_config(k, v) | rd_kafka_conf])
    end
  end

  defp filter_topic_config([], exrdkafka_acc, rd_kafka_conf),
    do: {:ok, exrdkafka_acc, rd_kafka_conf}

  defp filter_kafka_config([{k, v} = h | t], exrdkafka_acc, rd_kafka_conf) do
    case is_exrdkafka_config?(h) do
      true -> filter_kafka_config(t, [h | exrdkafka_acc], rd_kafka_conf)
      _ -> filter_kafka_config(t, exrdkafka_acc, [to_librdkafka_config(k, v) | rd_kafka_conf])
    end
  end

  defp filter_kafka_config([], exrdkafka_acc, rd_kafka_conf),
    do: {:ok, exrdkafka_acc, rd_kafka_conf}

  defp is_exrdkafka_topic_config(_, _), do: false

  defp is_exrdkafka_config?({:delivery_report_callback, _k} = kv), do: check_callback(kv, 2)
  defp is_exrdkafka_config?({:stats_callback, _k} = kv), do: check_callback(kv, 2)

  defp is_exrdkafka_config?({:queue_buffering_overflow_strategy, v}) do
    case v do
      :local_disk_queue -> true
      :block_calling_process -> true
      :drop_records -> true
      _ -> throw({:error, {:options, v}})
    end
  end

  defp is_exrdkafka_config?(_), do: false

  defp to_librdkafka_topic_config(_request_required_acks, v),
    do: {<<"request.required.acks">>, Utils.to_binary(v)}

  defp to_librdkafka_config(:builtin_features, v),
    do: {<<"builtin_features">>, Utils.to_binary(v)}

  defp to_librdkafka_config(:debug, v), do: {<<"debug">>, Utils.to_binary(v)}

  defp to_librdkafka_config(:connections_max_idle_ms, v),
    do: {<<"connections.max.idle.ms">>, Utils.to_binary(v)}

  defp to_librdkafka_config(:delivery_report_only_error, v),
    do: {<<"delivery.report.only.error">>, Utils.to_binary(v)}

  defp to_librdkafka_config(:client_id, v), do: {<<"client.id">>, Utils.to_binary(v)}

  defp to_librdkafka_config(:bootstrap_servers, v),
    do: {<<"bootstrap.servers">>, Utils.to_binary(v)}

  defp to_librdkafka_config(:message_max_bytes, v),
    do: {<<"message.max.bytes">>, Utils.to_binary(v)}

  defp to_librdkafka_config(:socket_keepalive_enable, v),
    do: {<<"socket.keepalive.enable">>, Utils.to_binary(v)}

  defp to_librdkafka_config(k, v), do: throw({:error, {:options, {k, v}}})

  defp check_callback(_h, _arity) do
    # case function?(v, arity) or is_atom(v) do
    #   false -> throw({:error, {:options, {k, v}}})
    #   _ -> true
    # end

    true
  end
end
