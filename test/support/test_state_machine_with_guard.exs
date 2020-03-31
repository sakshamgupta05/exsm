defmodule ExsmTest.TestStateMachineWithGuard do
  use Exsm,
    field: :my_state,
    states: ["created", "partial", "completed", "canceled"],
    transitions: %{
      "created" => ["partial", "completed"],
      "partial" => "completed"
    }

  def before_transition(struct, _prev_state, "completed") do
    # Code to simulate and force an exception inside a
    # guard function.
    if Map.get(struct, :force_exception) do
      Exsm.non_existing_function_should_raise_error()
    end

    no_missing_fields = Map.get(struct, :missing_fields) == false

    if no_missing_fields do
      {:ok, struct}
    else
      {:error, "Guard Condition Custom Cause"}
    end
  end

  def before_transition(struct, _prev_state, "canceled") do
    # Code to simulate and force an exception inside a
    # guard function.
    if Map.get(struct, :force_exception) do
      Exsm.non_existing_function_should_raise_error()
    end

    no_missing_fields = Map.get(struct, :missing_fields) == false

    if no_missing_fields do
      {:ok, struct}
    else
      {:error, "Guard Condition Custom Cause"}
    end
  end

  def log_transition(struct, _prev_state, _next_state) do
    # Log transition here
    if Map.get(struct, :force_exception) do
      Exsm.non_existing_function_should_raise_error()
    end

    struct
  end
end
