defmodule BeamCampusWeb.ColocatedHooksTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Every colocated hook must define the methods it calls on itself.

  ## Why this exists

  On 2026-08-05 the biotope's "one world" map had been blank for as long as it
  had existed. Its hook called `this.fitWorld()` in `mounted()`, on `resize` and
  on `dblclick`, and `this.at()` in the wheel handler. **Neither function was
  ever defined.** `mounted()` therefore threw `TypeError: this.fitWorld is not a
  function` before its first paint, and a hook that raises in `mounted` fails
  silently: the page renders, the element is there, nothing is drawn, and no
  test, no compiler and no LiveView assertion says a word.

  Two more faults hid behind it, both invisible for the same reason: `fit()`
  read `dataset.width`/`dataset.height` when the element carries `data-world-*`
  (so the backing store was sized `NaN`), and `paint()` never applied the camera
  that every drag and wheel event was carefully updating.

  ## What this catches, and what it does not

  It is a text scan, not a JS parser: it reads the `this.foo(` calls in each
  colocated hook and checks each one is either defined as a method in the same
  object, assigned as a property, or part of the LiveView hook API. That will
  not catch a wrong argument or a wrong attribute name. It catches the class of
  fault that actually shipped — calling something that does not exist — and it
  is worth having precisely because the runtime consequence is silence.
  """

  @live_dir Path.expand("../../lib/beam_campus_web/live", __DIR__)

  # Provided by LiveView on the hook object itself.
  @framework ~w(handleEvent pushEvent pushEventTo upload uploadTo)

  test "every colocated hook defines the methods it calls" do
    for {file, hook, missing} <- undefined_calls(), missing != [] do
      flunk("""
      #{Path.basename(file)} hook .#{hook} calls #{inspect(missing)}, \
      which it never defines. A hook that throws in mounted/0 fails silently: \
      the element renders and stays empty.\
      """)
    end
  end

  # ⚠ THE CHECK CAN FIND SOMETHING, and the fixtures are indented the way a real
  # hook is, because the scan keys on a method opening a line. A fixture written
  # on one line reports every method as undefined and the test above would pass
  # for the wrong reason.
  test "the scan can actually find a missing method" do
    assert missing_in("""
             mounted() {
               this.fitWorld()
               this.paint(1)
             },
             paint(e) {
             }
           """) == ["fitWorld"]
  end

  test "a method that is defined, or assigned, is not reported" do
    assert missing_in("""
             mounted() {
               this.paint(1)
             },
             paint(e) {
             }
           """) == []

    # Assigned as a property rather than defined as a method — the `toggle`
    # and `resize` handlers in the biotope hooks are both this shape.
    assert missing_in("""
             mounted() {
               this.resize = () => {}
               this.resize()
             }
           """) == []
  end

  defp undefined_calls do
    @live_dir
    |> Path.join("**/*.ex")
    |> Path.wildcard()
    |> Enum.flat_map(fn file ->
      file
      |> File.read!()
      |> hooks()
      |> Enum.map(fn {hook, body} -> {file, hook, missing_in(body)} end)
    end)
  end

  defp hooks(source) do
    ~r/ColocatedHook\}\s+name="\.(\w+)">(.*?)<\/script>/s
    |> Regex.scan(source)
    |> Enum.map(fn [_all, hook, body] -> {hook, body} end)
  end

  defp missing_in(body) do
    called = captures(~r/this\.(\w+)\(/, body)
    defined = captures(~r/^\s{2,}(\w+)\(/m, body)
    assigned = captures(~r/this\.(\w+)\s*=/, body)

    called
    |> MapSet.difference(defined)
    |> MapSet.difference(assigned)
    |> MapSet.difference(MapSet.new(@framework))
    |> Enum.sort()
  end

  defp captures(regex, body) do
    regex |> Regex.scan(body) |> Enum.map(fn [_all, name] -> name end) |> MapSet.new()
  end
end
