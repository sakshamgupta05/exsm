defmodule Exsm.Transition do
  @moduledoc """
  Exsm module responsible for control transitions,
  guard functions and callbacks (before and after).
  This is meant to be for internal use only.
  """

  @doc """
  Function responsible for checking if the transition from a state to another
  was specifically declared.
  This is meant to be for internal use only.
  """
  @spec declared_transition?(list, atom, atom) :: boolean
  def declared_transition?(transitions, prev_state, next_state) do
    if matches_wildcard?(transitions, next_state) do
      true
    else
      matches_transition?(transitions, prev_state, next_state)
    end
  end

  @doc """
  Function responsible to run all before_transitions callbacks or
  fallback to a boilerplate behaviour.
  This is meant to be for internal use only.
  """
  @spec before_callbacks(struct, atom, atom, module) :: {:ok, struct} | {:error, String.t()}
  def before_callbacks(struct, prev_state, next_state, module) do
    case run_or_fallback(
           &module.before_transition/3,
           &before_fallback/4,
           struct,
           prev_state,
           next_state,
           module._field()
         ) do
      {:ok, struct} -> {:ok, struct}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Function responsible to run all after_transitions callbacks or
  fallback to a boilerplate behaviour.
  This is meant to be for internal use only.
  """
  @spec after_callbacks(struct, atom, atom, module) :: struct
  def after_callbacks(struct, prev_state, next_state, module) do
    run_or_fallback(
      &module.after_transition/3,
      &after_fallback/4,
      struct,
      prev_state,
      next_state,
      module._field()
    )
  end

  @doc """
  This function will try to trigger persistence, if declared, to the struct
  changing state.
  This is meant to be for internal use only.
  """
  @spec persist_struct(struct, atom, atom, module) :: struct
  def persist_struct(struct, prev_state, next_state, module) do
    run_or_fallback(
      &module.persist/3,
      &persist_fallback/4,
      struct,
      prev_state,
      next_state,
      module._field()
    )
  end

  @doc """
  Function resposible for triggering transitions persistence.
  This is meant to be for internal use only.
  """
  @spec log_transition(struct, atom, atom, module) :: struct
  def log_transition(struct, prev_state, next_state, module) do
    run_or_fallback(
      &module.log_transition/3,
      &log_transition_fallback/4,
      struct,
      prev_state,
      next_state,
      module._field()
    )
  end

  defp matches_wildcard?(transitions, next_state) do
    matches_transition?(transitions, "*", next_state)
  end

  defp matches_transition?(transitions, prev_state, next_state) do
    case Map.fetch(transitions, prev_state) do
      {:ok, declared_states} when is_list(declared_states) ->
        Enum.member?(declared_states, next_state)

      :error ->
        false
    end
  end

  # Private function that receives a function, a callback,
  # a struct and the related state. It tries to execute the function,
  # rescue for a couple of specific Exceptions and passes it forward
  # to the callback, that will re-raise it if not related to
  # guard_transition nor before | after call backs
  defp run_or_fallback(func, callback, struct, prev_state, next_state, field) do
    func.(struct, prev_state, next_state)
  rescue
    error in UndefinedFunctionError -> callback.(struct, next_state, error, field)
    error in FunctionClauseError -> callback.(struct, next_state, error, field)
  end

  defp before_fallback(struct, _state, error, _field) do
    if error.function == :before_transition && error.arity == 3 do
      {:ok, struct}
    else
      raise error
    end
  end

  defp persist_fallback(struct, state, error, field) do
    if error.function == :persist && error.arity == 3 do
      Map.put(struct, field, state)
    else
      raise error
    end
  end

  defp log_transition_fallback(struct, _state, error, _field) do
    if error.function == :log_transition && error.arity == 3 do
      struct
    else
      raise error
    end
  end

  defp after_fallback(struct, _state, error, _field) do
    if error.function == :after_transition && error.arity == 3 do
      struct
    else
      raise error
    end
  end
end
