%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: []
      },
      checks: [
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, false}
      ]
    }
  ]
}
