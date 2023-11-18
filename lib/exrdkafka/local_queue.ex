defmodule Exrdkafka.LocalQueue do
  @moduledoc """
  Documentation for `Exrdkafka.LocalQueue`.
  """

  alias Exrdkafka.Utils
  require Logger

  def new(client_id) do
    client_id = Atom.to_string(client_id)
    path = Utils.get_priv_path(client_id) |> String.to_charlist()

    Logger.info("persistent queue path: #{inspect(path)}")
    :esq.new(path)
  end

  def free(:undefined), do: :ok
  def free(queue), do: :esq.free(queue)

  def enq(queue, topic_name, partition, key, value, headers, timestamp) do
    :esq.enq({topic_name, partition, key, value, headers, timestamp}, queue)
  end

  def deq(queue), do: :esq.deq(queue)

  def head(queue), do: :esq.head(queue)
end
