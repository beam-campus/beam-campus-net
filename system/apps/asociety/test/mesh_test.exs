defmodule ASociety.MeshTest do
  use ExUnit.Case, async: true

  describe "the pool this app opens" do
    # ⚠ A station refuses a pool whose identity fails the S/Kademlia puzzle,
    # and the refusal is quiet: the pool never gets a healthy link and the page
    # stays empty. The SDK generates that identity, so this checks the one the
    # SDK really hands this app. The first 8 bits of sha256 of its public key
    # must be zero, macula_identity's default difficulty. No station is needed:
    # the seed is a closed local port, and the key comes from the pool's status.
    test "has an identity a station accepts" do
      {:ok, pool} = ASociety.Mesh.open_pool(["https://127.0.0.1:1"])

      try do
        {:ok, %{self_node_id: public_key}} = :macula.status(pool)
        assert <<0::8, _rest::bitstring>> = :crypto.hash(:sha256, public_key)
      after
        :macula.close(pool)
      end
    end
  end
end
