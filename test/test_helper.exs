ExUnit.start()

import ExUnit.CaptureLog

# Load support modules
Code.compile_file("test/support/test_struct.exs")
Code.compile_file("test/support/test_default_field_struct.exs")
Code.compile_file("test/support/test_state_machine.exs")
Code.compile_file("test/support/test_state_machine_with_guard.exs")
Code.compile_file("test/support/test_state_machine_default_field.exs")
Code.compile_file("test/support/test_repo.exs")

defmodule ExsmTest.Helper do
  alias ExsmTest.TestRepo
  alias ExsmTest.TestStateMachine
  alias ExsmTest.TestStruct

  @doc false
  def exsm_interface(enable \\ true, genserver \\ true) do
    Application.put_env(:exsm, :module, TestStateMachine)
    Application.put_env(:exsm, :model, TestStruct)
    Application.put_env(:exsm, :repo, TestRepo)
    Application.put_env(:exsm, :interface, enable)
    Application.put_env(:exsm, :genserver, genserver)

    if genserver do
      capture_log(fn ->
        restart_machinery()
      end)
    end

    :ok
  end

  @doc false
  def restart_machinery() do
    supervisor_pid = Process.whereis(Machinery.Supervisor)
    Process.monitor(supervisor_pid)
    Process.exit(supervisor_pid, :kill)

    receive do
      _ ->
        :timer.sleep(5)
        Application.start(:machinery)
    end
  end
end
