ExUnit.start()

# Load support modules
Code.load_file("test/support/test_struct.exs")
Code.load_file("test/support/test_default_field_struct.exs")
Code.load_file("test/support/test_state_machine.exs")
Code.load_file("test/support/test_state_machine_with_guard.exs")
Code.load_file("test/support/test_state_machine_default_field.exs")
Code.load_file("test/support/test_repo.exs")

defmodule ExsmTest.Helper do
  import ExUnit.CaptureLog

  alias ExsmTest.TestRepo
  alias ExsmTest.TestStateMachine
  alias ExsmTest.TestStruct

  @doc false
  def exsm_interface(enable \\ true) do
    Application.put_env(:exsm, :module, TestStateMachine)
    Application.put_env(:exsm, :model, TestStruct)
    Application.put_env(:exsm, :repo, TestRepo)
    Application.put_env(:exsm, :interface, enable)

    :ok
  end
end
