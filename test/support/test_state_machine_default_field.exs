defmodule ExsmTest.TestStateMachineDefaultField do
  use Exsm,
    states: ["created", "canceled"],
    transitions: %{
      "*" => "canceled"
    }
end
