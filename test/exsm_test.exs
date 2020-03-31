defmodule ExsmTest do
  use ExUnit.Case, async: false
  # doctest Exsm

  alias ExsmTest.Helper
  alias ExsmTest.TestDefaultFieldStruct
  alias ExsmTest.TestStateMachine
  alias ExsmTest.TestStateMachineDefaultField
  alias ExsmTest.TestStateMachineWithGuard
  alias ExsmTest.TestStruct

  setup do
    Helper.exsm_interface()
  end

  test "All internal functions should be injected into AST" do
    assert :erlang.function_exported(TestStateMachine, :_exsm_initial_state, 0)
    assert :erlang.function_exported(TestStateMachine, :_exsm_states, 0)
    assert :erlang.function_exported(TestStateMachine, :_exsm_transitions, 0)
    assert :erlang.function_exported(TestStateMachine, :_field, 0)
  end

  test "Only the declared transitions should be valid" do
    created_struct = %TestStruct{my_state: "created", missing_fields: false}
    partial_struct = %TestStruct{my_state: "partial", missing_fields: false}
    stateless_struct = %TestStruct{}
    completed_struct = %TestStruct{my_state: "completed"}

    assert Exsm.valid_transition?(created_struct, TestStateMachine, "partial")

    assert {:ok, %TestStruct{my_state: "partial"}} =
             Exsm.transition_to(created_struct, TestStateMachine, "partial")

    assert Exsm.valid_transition?(created_struct, TestStateMachine, "completed")

    assert {:ok, %TestStruct{my_state: "completed", missing_fields: false}} =
             Exsm.transition_to(created_struct, TestStateMachine, "completed")

    assert Exsm.valid_transition?(partial_struct, TestStateMachine, "completed")

    assert {:ok, %TestStruct{my_state: "completed", missing_fields: false}} =
             Exsm.transition_to(partial_struct, TestStateMachine, "completed")

    refute Exsm.valid_transition?(stateless_struct, TestStateMachine, "created")

    assert {:error, "Transition to this state isn't declared."} =
             Exsm.transition_to(stateless_struct, TestStateMachine, "created")

    refute Exsm.valid_transition?(completed_struct, TestStateMachine, "created")

    assert {:error, "Transition to this state isn't declared."} =
             Exsm.transition_to(completed_struct, TestStateMachine, "created")
  end

  test "Wildcard transitions should be valid" do
    created_struct = %TestStruct{my_state: "created", missing_fields: false}
    partial_struct = %TestStruct{my_state: "partial", missing_fields: false}
    completed_struct = %TestStruct{my_state: "completed"}

    assert Exsm.valid_transition?(created_struct, TestStateMachine, "canceled")

    assert {:ok, %TestStruct{my_state: "canceled", missing_fields: false}} =
             Exsm.transition_to(created_struct, TestStateMachine, "canceled")

    assert Exsm.valid_transition?(partial_struct, TestStateMachine, "canceled")

    assert {:ok, %TestStruct{my_state: "canceled", missing_fields: false}} =
             Exsm.transition_to(partial_struct, TestStateMachine, "canceled")

    assert Exsm.valid_transition?(completed_struct, TestStateMachine, "canceled")

    assert {:ok, %TestStruct{my_state: "canceled"}} =
             Exsm.transition_to(completed_struct, TestStateMachine, "canceled")
  end

  test "Before callback should not be executed if the transition is invalid" do
    struct = %TestStruct{my_state: "created", missing_fields: true, force_exception: true}

    assert {:error, _cause} = Exsm.transition_to(struct, TestStateMachineWithGuard, "canceled")
  end

  test "Before callback should be executed before moving the resource to the next state" do
    struct = %TestStruct{my_state: "created", missing_fields: true}

    assert {:error, _cause} = Exsm.transition_to(struct, TestStateMachineWithGuard, "completed")
  end

  test "Before callback should allow or block transitions" do
    allowed_struct = %TestStruct{my_state: "created", missing_fields: false}
    blocked_struct = %TestStruct{my_state: "created", missing_fields: true}

    assert {:ok, %TestStruct{my_state: "completed", missing_fields: false}} =
             Exsm.transition_to(allowed_struct, TestStateMachineWithGuard, "completed")

    assert {:error, _cause} =
             Exsm.transition_to(blocked_struct, TestStateMachineWithGuard, "completed")
  end

  test "Before callback should return an error cause" do
    blocked_struct = %TestStruct{my_state: "created", missing_fields: true}

    assert {:error, "Guard Condition Custom Cause"} =
             Exsm.transition_to(blocked_struct, TestStateMachineWithGuard, "completed")
  end

  test "The first declared state should be considered the initial one" do
    stateless_struct = %TestStruct{}

    assert {:ok, %TestStruct{my_state: "partial"}} =
             Exsm.transition_to(stateless_struct, TestStateMachine, "partial")
  end

  test "Modules without before callbacks should allow transitions by default" do
    struct = %TestStruct{my_state: "created"}

    assert {:ok, %TestStruct{my_state: "completed"}} =
             Exsm.transition_to(struct, TestStateMachine, "completed")
  end

  @tag :capture_log
  test "Implict rescue on the before callback internals should raise any other excepetion not strictly related to missing before_transition/3 existence" do
    wrong_struct = %TestStruct{my_state: "created", force_exception: true}

    assert_raise UndefinedFunctionError, fn ->
      Exsm.transition_to(wrong_struct, TestStateMachineWithGuard, "completed")
    end
  end

  test "after_transition/3 and before_transition/3 callbacks should be automatically executed" do
    struct = %TestStruct{}
    assert struct.missing_fields == nil

    {:ok, partial_struct} = Exsm.transition_to(struct, TestStateMachine, "partial")
    assert partial_struct.missing_fields == true

    {:ok, completed_struct} = Exsm.transition_to(struct, TestStateMachine, "completed")
    assert completed_struct.missing_fields == false
  end

  @tag :capture_log
  test "Implict rescue on the callbacks internals should raise any other excepetion not strictly related to missing fallback existence" do
    wrong_struct = %TestStruct{my_state: "created", force_exception: true}

    assert_raise UndefinedFunctionError, fn ->
      Exsm.transition_to(wrong_struct, TestStateMachine, "partial")
    end
  end

  test "Persist function should be called after the transition" do
    struct = %TestStruct{my_state: "partial"}
    assert {:ok, _} = Exsm.transition_to(struct, TestStateMachine, "completed")
  end

  @tag :capture_log
  test "Persist function should still raise errors if not related to the existence of persist/1 method" do
    wrong_struct = %TestStruct{my_state: "created", force_exception: true}

    assert_raise UndefinedFunctionError, fn ->
      Exsm.transition_to(wrong_struct, TestStateMachine, "completed")
    end
  end

  test "After transition function should still raise errors if not related to the existence of after_transition/1 method" do
    wrong_struct = %{state: "created", force_exception: true}

    assert_raise UndefinedFunctionError, fn ->
      Exsm.transition_to(wrong_struct, TestStateMachineDefaultField, "canceled")
    end
  end

  @tag :capture_log
  test "Transition log function should still raise errors if not related to the existence of persist/1 method" do
    wrong_struct = %TestStruct{my_state: "created", force_exception: true}

    assert_raise UndefinedFunctionError, fn ->
      Exsm.transition_to(wrong_struct, TestStateMachineWithGuard, "partial")
    end
  end

  test "Transition log function should be called after the transition" do
    struct = %TestStruct{my_state: "created"}
    assert {:ok, _} = Exsm.transition_to(struct, TestStateMachineWithGuard, "partial")
  end

  test "Should use default state name if not specified" do
    struct = %TestDefaultFieldStruct{state: "created"}

    assert {:ok, %TestDefaultFieldStruct{state: "canceled"}} =
             Exsm.transition_to(struct, TestStateMachineDefaultField, "canceled")
  end
end
