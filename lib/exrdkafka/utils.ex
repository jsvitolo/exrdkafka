defmodule Exrdkafka.Utils do
  @moduledoc """
  Documentation for `Exrdkafka.Utils`.
  """

  def get_priv_path(file) do
    case :code.priv_dir(:exrdkafka) do
      {:error, :bad_name} ->
        ebin = Path.dirname(:code.which(__MODULE__))
        Path.join([Path.dirname(ebin), "priv", file])

      dir ->
        Path.join(dir, file)
    end
  end

  def get_env(key), do: get_env(key, :undefined)

  def get_env(key, default) do
    case Application.get_env(:exrdkafka, key) do
      :undefined -> default
      val -> val
    end
  end

  def lookup(key, list), do: lookup(key, list, :undefined)

  def lookup(key, list, default) do
    case Enum.find(list, fn {k, _} -> k == key end) do
      {_, result} -> result
      _ -> default
    end
  end

  def append_props(l1, [{k, _} = h | t]) do
    case lookup(k, l1) do
      :undefined -> append_props([h | l1], t)
      _ -> append_props(l1, t)
    end
  end

  def append_props(client_config, nil), do: client_config

  def to_binary(v) when is_binary(v), do: v
  def to_binary(v) when is_list(v), do: List.to_string(v)
  def to_binary(v) when is_atom(v), do: Atom.to_string(v)
  def to_binary(v) when is_integer(v), do: Integer.to_string(v)
  def to_binary(v) when is_float(v), do: float_to_bin(v)

  def float_to_bin(value), do: :erlang.float_to_binary(value, decimals: 8, compact: true)

  def safe_call(receiver, message), do: safe_call(receiver, message, 5000)

  def safe_call(receiver, message, timeout) do
    try do
      GenServer.call(receiver, message, timeout)
    catch
      :exit, {:noproc, _} -> {:error, :not_started}
      _, exception -> {:error, exception}
    end
  end

  def call_stats_callback(:undefined, _client_id, _stats), do: :ok
  def call_stats_callback(c, client_id, stats) when is_function(c, 2), do: c.(client_id, stats)
  def call_stats_callback(c, client_id, stats), do: c.stats_callback(client_id, stats)

  def parallel_exec(fun, list) do
    parent = self()

    pids =
      Enum.map(list, fn e ->
        spawn_link(fn ->
          fun.(e)
          send(parent, {self(), :done})
        end)
      end)

    Enum.each(pids, fn pid ->
      receive do
        {^pid, :done} -> :ok
      end
    end)

    :ok
  end
end
