defmodule Exrdkafka.Clients do
  @moduledoc """
  Documentation for `Exrdkafka.Clients`.
  """
  use GenServer

  alias Exrdkafka.Utils

  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    start_clients()

    {:ok, %{}}
  end

  defp start_clients do
    case Utils.get_env(:clients) do
      :undefined -> :ok
      value -> Enum.each(value, &start_client/1)
    end
  end

  defp start_client({client_id, c}) do
    type = Utils.lookup(:type, c)
    client_opts = Utils.lookup(:client_options, c, [])
    topics = Utils.lookup(:topics, c, [])

    case type do
      :producer ->
        :ok = Exrdkafka.create_producer(client_id, client_opts)
        Logger.info("producer #{inspect(client_id)} created")
        :ok = create_topics(client_id, topics)

      :consumer ->
        group_id = Utils.lookup(:group_id, c)
        default_topics_config = Utils.lookup(:topic_options, c, [])

        :ok =
          Exrdkafka.create_consumer_group(
            client_id,
            group_id,
            topics,
            client_opts,
            default_topics_config
          )

        Logger.info("consumer #{inspect(client_id)} created")
    end
  end

  defp create_topics(client_id, [h | t]) do
    case h do
      {topic_name, topic_opts} ->
        :ok = Exrdkafka.create_topic(client_id, topic_name, topic_opts)
        Logger.info("topic #{inspect(topic_name)} created over client: #{inspect(client_id)}")

      topic_name when is_binary(topic_name) ->
        :ok = Exrdkafka.create_topic(client_id, topic_name)
        Logger.info("topic #{inspect(topic_name)} created over client: #{inspect(client_id)}")
    end

    create_topics(client_id, t)
  end

  defp create_topics(_client_id, []), do: :ok
end
