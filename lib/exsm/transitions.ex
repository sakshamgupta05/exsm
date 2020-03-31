defmodule Exsm.Transitions do
  @moduledoc """
  This is a GenServer that controls the transitions for a struct
  using a set of helper functions from Exsm.Transition
  It's meant to be run by a supervisor.
  """

  alias Exsm.Transition

  @not_declated_error "Transition to this state isn't declared."
  @invalid_transitions_error "Invalid transitions defined"

  @doc false
  def transition_to(struct, state_machine_module, next_state) do
    initial_state = state_machine_module._exsm_initial_state()
    transitions = state_machine_module._exsm_transitions()
    state_field = state_machine_module._field()

    # Getting current state of the struct or falling back to the
    # first declared state on the struct model.
    prev_state =
      case Map.get(struct, state_field) do
        nil -> initial_state
        prev_state -> prev_state
      end

    # Checking declared transitions and guard functions before
    # actually updating the struct and retuning the tuple.
    declared_transition? = Transition.declared_transition?(transitions, prev_state, next_state)

    response =
      if declared_transition? do
        case Transition.before_callbacks(struct, prev_state, next_state, state_machine_module) do
          {:ok, struct} ->
            struct =
              struct
              |> Transition.persist_struct(prev_state, next_state, state_machine_module)
              |> Transition.log_transition(prev_state, next_state, state_machine_module)
              |> Transition.after_callbacks(prev_state, next_state, state_machine_module)

            {:ok, struct}

          {:error, reason} ->
            {:error, reason}
        end
      else
        {:error, @not_declated_error}
      end

    response
  end

  @doc false
  def valid_transition?(struct, state_machine_module, next_state) do
    initial_state = state_machine_module._exsm_initial_state()
    transitions = state_machine_module._exsm_transitions()
    state_field = state_machine_module._field()

    # Getting current state of the struct or falling back to the
    # first declared state on the struct model.
    prev_state =
      case Map.get(struct, state_field) do
        nil -> initial_state
        prev_state -> prev_state
      end

    # Checking declared transitions and guard functions before
    # actually updating the struct and retuning the tuple.
    Transition.declared_transition?(transitions, prev_state, next_state)
  end

  def parse_transitions(transitions, states) do
    validate_transitions!(transitions, states)

    Map.keys(transitions)
    |> Enum.reduce(%{}, &reduce_transitions(transitions, states, &1, &2))
  end

  defp validate_transitions!(transitions, states) do
    Map.keys(transitions)
    |> Enum.each(fn key ->
      validate_state!(key, states)
      validate_state!(transitions[key], states)
    end)
  end

  defp validate_state!("*", _states), do: nil

  defp validate_state!("^", _states), do: nil

  defp validate_state!(value, states) when is_binary(value) do
    unless value in states do
      raise "Transition is defined but corresponding state is not declared"
    end
  end

  defp validate_state!(value, states) when is_list(value) do
    Enum.each(value, &validate_state!(&1, states))
  end

  defp validate_state!(_value, _states), do: raise(@invalid_transitions_error)

  defp reduce_transitions(transitions, states, key, acc) do
    cond do
      key in ["*", "^"] && transitions[key] in ["*", "^"] ->
        raise "Invalid transition declaration: key and value both cannot be wildcard"

      key == "*" ->
        Enum.reduce(states, acc, fn k, a ->
          Map.put(a, k, append_value(states, Map.get(a, k, []), k, transitions[key]))
        end)

      key == "^" ->
        value =
          case transitions[key] do
            value when is_binary(value) -> [value]
            value when is_list(value) -> value
          end

        Enum.reduce(states, acc, fn k, a ->
          Map.put(a, k, append_value(states, Map.get(a, k, []), k, value -- [k]))
        end)

      is_binary(key) ->
        Map.put(acc, key, append_value(states, Map.get(acc, key, []), key, transitions[key]))

      is_list(key) ->
        Enum.reduce(key, acc, fn k, a ->
          Map.put(a, k, append_value(states, Map.get(a, k, []), k, transitions[key]))
        end)
    end
  end

  defp append_value(states, prev_value, key, value) do
    value =
      cond do
        value == "*" -> states
        value == "^" -> states -- [key]
        is_binary(value) -> [value]
        is_list(value) -> value
      end

    Enum.reduce(value, prev_value, fn v, a ->
      if v in a do
        a
      else
        a ++ [v]
      end
    end)
  end
end
