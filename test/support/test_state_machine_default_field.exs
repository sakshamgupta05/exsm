defmodule ExsmTest.TestStateMachineDefaultField do
  use Exsm,
    states: ["created", "canceled"],
    transitions: %{
      "*" => "canceled"
    }

  def after_transition(struct, _prev_state, next_state) do
    # Code to simulate and force an exception inside a
    # guard function.
    if Map.get(struct, :force_exception) do
      Exsm.non_existing_function_should_raise_error()
    end

    Map.put(struct, :state, next_state)
  end
end
