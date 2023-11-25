defmodule Exrdkafka.ConsumerCallback do
  @moduledoc """
  Documentation for `Exrdkafka.ConsumerCallback`.
  """

  @type state :: map()
  @type client_id :: atom()
  @type message :: map()

  @callback init(binary(), integer(), integer(), any()) :: {:ok, any}
  @callback handle_message(message(), state()) :: {:ok, state()} | {:error, any(), state()}
  @callback stats_callback(client_id, map()) :: :ok

  @optional_callbacks stats_callback: 2
end
