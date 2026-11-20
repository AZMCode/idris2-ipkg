{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      ps = inputs.packageset.packages.${system};
    in
    {
      devShells.default = pkgs.mkShell {
        name = "ipkg-render";

        packages = [
          ps.idris2
          ps.idris2Lsp
          pkgs.idris2Packages.pack
          pkgs.jq
        ];

        shellHook = ''
          echo "ipkg-render dev shell"
          echo "  nix build && ./result/bin/ipkg-render < tests/fixture.json"
          echo "  nix flake check"
        '';
      };
    };
}
