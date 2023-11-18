defmodule Exrdkafka.ProducerCallbacks do
  @moduledoc """
  Documentation for `Exrdkafka.ProducerCallbacks`.
  """

  @callback delivery_report(delivery_status :: :ok | {:error, any()}, message :: map()) :: :ok
  @callback stats_callback(client_id :: any(), stats :: map()) :: :ok
  @optional_callbacks [stats_callback: 2, delivery_report: 2]
end
