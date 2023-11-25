defmodule Exrdkafka.Config do
  @moduledoc """
  Documentation for `ExrdkafkaConfig`.
  """

  alias Exrdkafka.Utils

  @kafka_config_keys [
    :builtin_features,
    :debug,
    :connections_max_idle_ms,
    :delivery_report_only_error,
    :client_id,
    :bootstrap_servers,
    :message_max_bytes,
    :message_copy_max_bytes,
    :receive_message_max_bytes,
    :max_in_flight,
    :metadata_request_timeout_ms,
    :statistics_interval_ms,
    :socket_keepalive_enable,
    :metadata_max_age_ms,
    :topic_metadata_refresh_interval_ms,
    :topic_metadata_refresh_fast_interval_ms,
    :topic_metadata_refresh_sparse,
    :topic_metadata_propagation_max_ms,
    :topic_blacklist,
    :socket_timeout_ms,
    :socket_send_buffer_bytes,
    :socket_receive_buffer_bytes,
    :socket_nagle_disable,
    :socket_max_fails,
    :broker_address_ttl,
    :broker_address_family,
    :reconnect_backoff_ms,
    :enabled_events,
    :log_level,
    :log_queue,
    :log_thread_name,
    :enable_random_seed,
    :log_connection_close,
    :api_version_request,
    :api_version_request_timeout_ms,
    :api_version_fallback_ms,
    :broker_version_fallback,
    :security_protocol,
    :ssl_cipher_suites,
    :ssl_curves_list,
    :ssl_sigalgs_list,
    :ssl_key_location,
    :ssl_key_password,
    :ssl_key_pem,
    :ssl_certificate_location,
    :ssl_certificate_pem,
    :ssl_ca_location,
    :ssl_crl_location,
    :ssl_keystore_location,
    :ssl_keystore_password,
    :enable_ssl_certificate_verification,
    :ssl_endpoint_identification_algorithm,
    :sasl_mechanisms,
    :sasl_kerberos_service_name,
    :sasl_kerberos_principal,
    :sasl_kerberos_kinit_cmd,
    :sasl_kerberos_keytab,
    :sasl_kerberos_min_time_before_relogin,
    :sasl_username,
    :sasl_password,
    :sasl_oauthbearer_config,
    :enable_sasl_oauthbearer_unsecure_jwt,
    :group_instance_id,
    :session_timeout_ms,
    :partition_assignment_strategy,
    :heartbeat_interval_ms,
    :group_protocol_type,
    :coordinator_query_interval_ms,
    :max_poll_interval_ms,
    :auto_commit_interval_ms,
    :queued_min_messages,
    :queued_max_messages_kbytes,
    :fetch_wait_max_ms,
    :fetch_message_max_bytes,
    :fetch_max_bytes,
    :fetch_min_bytes,
    :fetch_error_backoff_ms,
    :allow_auto_create_topics,
    :client_rack,
    :transactional_id,
    :transaction_timeout_ms,
    :check_crcs,
    :isolation_level,
    :enable_idempotence,
    :enable_gapless_guarantee,
    :queue_buffering_max_messages,
    :queue_buffering_max_kbytes,
    :queue_buffering_max_ms,
    :message_send_max_retries,
    :retry_backoff_ms,
    :queue_buffering_backpressure_threshold,
    :compression_codec,
    :batch_num_messages,
    :batch_size,
    :plugin_library_paths,
    :sticky_partitioning_linger_ms
  ]

  @topic_config_keys [
    :request_required_acks,
    :request_timeout_ms,
    :message_timeout_ms,
    :partitioner,
    :compression_codec,
    :compression_level,
    :auto_commit_interval_ms,
    :auto_offset_reset,
    :offset_store_path,
    :offset_store_sync_interval_ms,
    :consume_callback_max_messages
  ]

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

  defp is_exrdkafka_config?({:delivery_report_callback = k, v}), do: check_callback(k, v, 2)
  defp is_exrdkafka_config?({:stats_callback = k, v}), do: check_callback(k, v, 2)

  defp is_exrdkafka_config?({:queue_buffering_overflow_strategy, v}) do
    case v do
      :local_disk_queue -> true
      :block_calling_process -> true
      :drop_records -> true
      _ -> throw({:error, {:options, v}})
    end
  end

  defp is_exrdkafka_config?(_), do: false

  for key <- @kafka_config_keys do
    defp to_librdkafka_config(unquote(key), v) do
      key_string = Atom.to_string(unquote(key))
      kafka_key = String.replace(key_string, "_", ".")

      {String.to_charlist(kafka_key), Utils.to_binary(v)}
    end
  end

  defp to_librdkafka_config(k, v), do: throw({:error, {:options, {k, v}}})

  for key <- @topic_config_keys do
    defp to_librdkafka_topic_config(unquote(key), v) do
      key_string = Atom.to_string(unquote(key))
      kafka_key = String.replace(key_string, "_", ".")

      {String.to_charlist(kafka_key), Utils.to_binary(v)}
    end
  end

  defp to_librdkafka_topic_config(k, v), do: throw({:error, {:options, {k, v}}})

  def check_callback(k, v, arity) do
    case is_function(v, arity) or is_atom(v) do
      false ->
        throw({:error, {:options, {k, v}}})

      _ ->
        true
    end
  end
end
