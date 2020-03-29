defmodule Exsm do
  @moduledoc """
  This is the main Exsm module.

  It keeps most of the Exsm logics, it's the module that will be
  imported with `use` on the module responsible for the state machine.

  Declare the states as an argument when importing `Exsm` on the module
  that will control your states transitions.

  Exsm expects a `Keyword` as argument with two keys `states` and `transitions`.

  ## Parameters

    - `opts`: A Keyword including `states` and `transitions`.
      - `states`: A List of Strings representing each state.
      - `transitions`: A Map for each state and it allowed next state(s).

  ## Example
    ```
    defmodule YourProject.UserStateMachine do
      use Exsm,
        # The first state declared will be considered
        # the intial state
        states: ["created", "partial", "complete"],
        transitions: %{
          "created" =>  ["partial", "complete"],
          "partial" => "completed"
        }
    end
    ```
  """

  @doc """
  Main macro function that will be executed upon the load of the
  module using it.

  It basically stores the states and transitions.

  It expects a `Keyword` as argument with two keys `states` and `transitions`.

  - `states`: A List of Strings representing each state.
  - `transitions`: A Map for each state and it allowed next state(s).

  P.S. The first state declared will be considered the intial state
  """
  defmacro __using__(opts) do
    field = Keyword.get(opts, :field, :state)
    states = Keyword.get(opts, :states)
    transitions = Keyword.get(opts, :transitions)

    # Quoted response to be inserted on the abstract syntax tree (AST) of
    # the module that imported this using `use`.
    quote bind_quoted: [
            field: field,
            states: states,
            transitions: transitions
          ] do
      # Functions to hold and expose internal info of the states.
      def _exsm_initial_state(), do: List.first(unquote(states))
      def _exsm_states(), do: unquote(states)

      def _exsm_transitions() do
        unquote(Macro.escape(transitions)) |> Exsm.Transitions.parse_transitions(unquote(states))
      end

      def _field(), do: unquote(field)
    end
  end

  @doc """
  Triggers the transition of a struct to a new state, accordinly to a specific
  state machine module, if it passes any existing guard functions.
  It also runs any before or after callbacks and returns a tuple with
  `{:ok, struct}`, or `{:error, "reason"}`.

  ## Parameters

    - `struct`: The `struct` you want to transit to another state.
    - `state_machine_module`: The module that holds the state machine logic, where Exsm as imported.
    - `next_state`: String of the next state you want to transition to.

  ## Examples

      iex> Exsm.transition_to(%User{state: :partial}, UserStateMachine, :completed)
      {:ok, %User{state: :completed}}
  """
  @spec transition_to(struct, module, String.t()) :: {:ok, struct} | {:error, String.t()}
  def transition_to(struct, state_machine_module, next_state) do
    Exsm.Transitions.transition_to(
      struct,
      state_machine_module,
      next_state
    )
  end

  @doc """
  Returns true if transition is valid.

  ## Parameters

    - `struct`: The `struct` you want to transit to another state.
    - `state_machine_module`: The module that holds the state machine logic, where Exsm as imported.
    - `next_state`: String of the next state you want to transition to.

  ## Examples

      iex> Exsm.valid_transition?(%User{state: :partial}, UserStateMachine, :completed)
      true
  """
  @spec valid_transition?(struct, module, String.t()) :: true | false
  def valid_transition?(struct, state_machine_module, next_state) do
    Exsm.Transitions.valid_transition?(
      struct,
      state_machine_module,
      next_state
    )
  end
end
