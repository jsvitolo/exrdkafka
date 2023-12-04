defmodule ExrdkafkaTest do
  use ExUnit.Case
  doctest Exrdkafka

  defmodule Producer do
    @behaviour Exrdkafka.ProducerCallbacks

    def handle_delivery_report(_producer, _message, _opaque) do
      :ok
    end
  end

  defmodule Consumer do
    @moduledoc false

    @behaviour Exrdkafka.ConsumerCallback

    @impl Exrdkafka.ConsumerCallback
    def init(_topic, _partition, _offset, _args) do
      {:ok, %{}}
    end

    @impl Exrdkafka.ConsumerCallback
    def handle_message(_message, %{}) do
      {:ok, %{}}
    end

    @impl Exrdkafka.ConsumerCallback
    def stats_callback(_client, _stats) do
      :ok
    end
  end

  setup do
    :ok = Exrdkafka.start()

    Application.put_env(:exrdkafka, :global_client_options,
      bootstrap_servers: "localhost:9092",
      delivery_report_only_error: false,
      delivery_report_callback: ExrdkafkaTest.Producer,
      debug: :topic
    )

    on_exit(fn ->
      :ok = Exrdkafka.stop()
    end)
  end

  test "create_producer/2 creates a producer" do
    assert Exrdkafka.create_producer(:test_producer, socket_keepalive_enable: true)

    assert Exrdkafka.create_producer(:other_test_producer, [])

    assert {:error, :err_already_existing_client} = Exrdkafka.create_producer(:test_producer, [])
  end

  test "create_consumer_group/5 creates a consumer group" do
    client_id = :test_consumer
    group_id = "test_group"
    topics = [{"test_topic", [callback_module: ExrdkafkaTest.Consumer]}]
    client_config = []
    default_topics_config = []

    assert :ok =
             Exrdkafka.create_consumer_group(
               client_id,
               group_id,
               topics,
               client_config,
               default_topics_config
             )
  end
end
