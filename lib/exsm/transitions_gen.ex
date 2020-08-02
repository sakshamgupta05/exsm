defmodule Machinery.TransitionsGen do
  @moduledoc """
  This is a GenServer that controls the transitions for a struct
  using a set of helper functions from Machinery.Transition
  It's meant to be run by a supervisor.
  """

  use GenServer

  def init(args) do
    {:ok, args}
  end

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc false
  def handle_call({:run, struct, state_machine_module, next_state}, _from, states) do
    IO.inspect("==============")

    response =
      Exsm.Transitions.transition_to(
        struct,
        state_machine_module,
        next_state
      )

    {:reply, response, states}
  end
end
