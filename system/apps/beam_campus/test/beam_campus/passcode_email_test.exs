defmodule BeamCampus.PasscodeEmailTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias BeamCampus.PasscodeEmail

  @payload %{
    "to_email_address" => "Someone.Else@example.org",
    "subject" => "Use passcode 803893 to login to your account",
    "body_plain" => "Your passcode is 803893",
    "body" => "<p>Your passcode is 803893</p>"
  }

  setup do
    level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: level) end)
  end

  test "a sent passcode mail is logged without the passcode or the address" do
    log = capture_log(fn -> assert {:ok, _} = PasscodeEmail.deliver(@payload) end)

    assert log =~ "[PasscodeEmail] sent"
    assert log =~ "to_domain=example.org"
    assert log =~ ~r/to_hash=[0-9a-f]{12}/
    refute log =~ "803893"
    refute log =~ "Use passcode"
    refute String.downcase(log) =~ "someone.else"
  end
end
