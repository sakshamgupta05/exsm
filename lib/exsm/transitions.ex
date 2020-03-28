defmodule Exsm.Transitions do
  @moduledoc """
  This is a GenServer that controls the transitions for a struct
  using a set of helper functions from Exsm.Transition
  It's meant to be run by a supervisor.
  """

  alias Exsm.Transition

  @not_declated_error "Transition to this state isn't declared."

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
end
