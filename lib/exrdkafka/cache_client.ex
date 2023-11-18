defmodule Exrdkafka.CacheClient do
  @moduledoc """
  Documentation for `Exrdkafka.CacheClient`.
  """
  @ets_topic_cache :erlkaf_client_cache_tab

  def create() do
    :ets.new(@ets_topic_cache, [:set, :named_table, :public, {:read_concurrency, true}])
    :ok
  end

  def set(client_id, client_ref, client_pid) do
    :ets.insert(@ets_topic_cache, {client_id, {client_ref, client_pid}})
    :ok
  end

  def get(client_id) do
    case :ets.lookup(@ets_topic_cache, client_id) do
      [{^client_id, {client_ref, client_pid}}] ->
        {:ok, client_ref, client_pid}

      [] ->
        :undefined
    end
  end

  def take(client_id) do
    :ets.take(@ets_topic_cache, client_id)
  end

  def to_list() do
    :ets.tab2list(@ets_topic_cache)
  end
end
