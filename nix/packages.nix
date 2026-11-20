{ inputs, ... }:
{
  perSystem =
    { system, config, ... }:
    let
      ps = inputs.packageset.packages.${system};
    in
    {
      # The compiler's own package is installed under the name `idris2`, not
      # `idris2api` — that is the ipkg name, whatever the nixpkgs attribute is
      # called. `json` supplies the derived decoder.
      packages.ipkg-render = (ps.buildIdris {
        src = ../.;
        ipkgName = "ipkg-render";
        idrisLibraries = [
          ps.idris2Api
          ps.idris2Packages.packdb.json
        ];
      }).executable;

      packages.default = config.packages.ipkg-render;

      apps.ipkg-render = {
        type = "app";
        program = "${config.packages.ipkg-render}/bin/ipkg-render";
      };
    };
}
