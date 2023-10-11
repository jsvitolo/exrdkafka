defmodule ExrdkafkaTest do
  use ExUnit.Case
  doctest Exrdkafka

  test "greets the world" do
    assert Exrdkafka.hello() == :world
  end
end
