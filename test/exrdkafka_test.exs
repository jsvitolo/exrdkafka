defmodule ExrdkafkaTest do
  use ExUnit.Case
  doctest Exrdkafka

  defmodule Test.Producer do
    @behaviour Exrdkafka.ProducerCallbacks

    def handle_delivery_report(_producer, _message, _opaque) do
      :ok
    end
  end

  setup do
    :ok = Exrdkafka.start()

    Application.put_env(:exrdkafka, :global_client_options,
      bootstrap_servers: "localhost:9092",
      delivery_report_only_error: false,
      delivery_report_callback: Test.Producer,
      debug: :topic
    )

    on_exit(fn ->
      :ok = Exrdkafka.stop()
    end)
  end

  test "create producer" do
    assert Exrdkafka.create_producer(:test_producer, socket_keepalive_enable: true)

    assert Exrdkafka.create_producer(:other_test_producer, [])

    assert {:error, :err_already_existing_client} = Exrdkafka.create_producer(:test_producer, [])
  end
end
