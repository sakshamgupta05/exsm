defmodule ExsmTest.TransitionTest do
  use ExUnit.Case, async: false
  doctest Exsm.Transition
  alias Exsm.Transition
  alias Exsm.Transitions

  test "declared_transition?/3 based on a map of transitions, current and next state" do
    states = ["created", "partial", "completed"]

    transitions =
      %{
        "created" => ["partial", "completed"],
        "partial" => "completed"
      }
      |> Transitions.parse_transitions(states)

    assert Transition.declared_transition?(transitions, "created", "partial")
    assert Transition.declared_transition?(transitions, "created", "completed")
    assert Transition.declared_transition?(transitions, "partial", "completed")
    refute Transition.declared_transition?(transitions, "partial", "created")
  end

  test "declared_transition?/3 for a declared transition that allows transition for any state" do
    states = ["created", "completed", "canceled"]

    transitions =
      %{
        "created" => "completed",
        "*" => "canceled"
      }
      |> Transitions.parse_transitions(states)

    assert Transition.declared_transition?(transitions, "created", "completed")
    assert Transition.declared_transition?(transitions, "created", "canceled")
    assert Transition.declared_transition?(transitions, "completed", "canceled")
  end

  test "declared_transition?/3 for a declared transition that allows transition for any state - all combinations" do
    states = ["a", "b", "c", "d", "e", "f", "g", "h", "i"]

    transitions =
      %{
        "a" => "b",
        ["a"] => ["c", "d"],
        "b" => "^",
        "c" => "*",
        "*" => "e",
        "^" => ["f", "h"],
        ["a", "b", "c"] => "g",
        ["b", "c", "e"] => "d"
      }
      |> Transitions.parse_transitions(states)

    assert Transition.declared_transition?(transitions, "a", "b")
    assert Transition.declared_transition?(transitions, "a", "c")
    refute Transition.declared_transition?(transitions, "b", "b")
    assert Transition.declared_transition?(transitions, "b", "i")
    assert Transition.declared_transition?(transitions, "c", "c")
    assert Transition.declared_transition?(transitions, "c", "i")
    assert Transition.declared_transition?(transitions, "i", "e")
    assert Transition.declared_transition?(transitions, "e", "e")
    assert Transition.declared_transition?(transitions, "i", "f")
    refute Transition.declared_transition?(transitions, "f", "f")
    assert Transition.declared_transition?(transitions, "i", "h")
    refute Transition.declared_transition?(transitions, "h", "h")
    assert Transition.declared_transition?(transitions, "a", "g")
    assert Transition.declared_transition?(transitions, "e", "d")
  end

  test "invalid transitions - state not declared" do
    states = ["a", "b", "c"]

    transitions = %{
      "d" => "b"
    }

    assert_raise RuntimeError,
                 "Transition is defined but corresponding state is not declared",
                 fn ->
                   Transitions.parse_transitions(transitions, states)
                 end

    transitions = %{
      "b" => "e"
    }

    assert_raise RuntimeError,
                 "Transition is defined but corresponding state is not declared",
                 fn ->
                   Transitions.parse_transitions(transitions, states)
                 end
  end

  test "invalid transitions - unsupported characters" do
    states = ["a", "b", "c"]

    transitions = %{
      :a => "b"
    }

    assert_raise RuntimeError,
                 "Invalid transitions defined",
                 fn ->
                   Transitions.parse_transitions(transitions, states)
                 end

    transitions = %{
      "a" => :b
    }

    assert_raise RuntimeError,
                 "Invalid transitions defined",
                 fn ->
                   Transitions.parse_transitions(transitions, states)
                 end
  end

  test "invalid transitions - wildcard key & value" do
    states = ["a", "b", "c"]

    transitions = %{
      "*" => "^"
    }

    assert_raise RuntimeError,
                 "Invalid transition declaration: key and value both cannot be wildcard",
                 fn ->
                   Transitions.parse_transitions(transitions, states)
                 end

    transitions = %{
      "*" => "*"
    }

    assert_raise RuntimeError,
                 "Invalid transition declaration: key and value both cannot be wildcard",
                 fn ->
                   Transitions.parse_transitions(transitions, states)
                 end

    transitions = %{
      "^" => "^"
    }

    assert_raise RuntimeError,
                 "Invalid transition declaration: key and value both cannot be wildcard",
                 fn ->
                   Transitions.parse_transitions(transitions, states)
                 end
  end
end
