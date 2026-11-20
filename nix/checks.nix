{ inputs, ... }:
{
  perSystem =
    { pkgs, system, config, ... }:
    let
      ps = inputs.packageset.packages.${system};
      ipkgLib = import ../lib/mk-ipkg.nix { inherit (pkgs) lib; };

      renderer = config.packages.ipkg-render;

      # What a consumer actually writes: the ergonomic declaration, no PkgDesc
      # shapes anywhere. Must render to the same bytes as the JSON fixture.
      ergonomic = {
        package = "cryptosystem";
        version = "0.1.0";
        authors = "Adriano";
        license = "MIT";
        brief = "b";
        readme = "README.md";
        sourcedir = "src";
        opts = "--total";
        depends = [ "eff" ];
        modules = [
          "Crypto"
          "Crypto.Internal"
        ];
      };
    in
    {
      checks = {
        build = config.packages.ipkg-render;

        # Golden test: render a fixture and diff it against the expected file.
        # The output is the compiler's `pretty`, so this also pins the formatting
        # and will fail if the compiler changes it.
        golden = pkgs.runCommand "ipkg-render-golden" {
          nativeBuildInputs = [
            renderer
            pkgs.diffutils
          ];
        } ''
          ipkg-render < ${../tests/fixture.json} > actual.ipkg
          diff -u ${../tests/expected.ipkg} actual.ipkg
          touch $out
        '';

        # The Nix-side layer: declaration -> rewrite rules -> JSON -> .ipkg.
        lib-renders = pkgs.runCommand "ipkg-render-lib" {
          nativeBuildInputs = [ pkgs.diffutils ];
        } ''
          diff -u ${../tests/expected.ipkg} \
            ${ipkgLib.mkIpkg { inherit pkgs renderer; } ergonomic}
          touch $out
        '';

        # A malformed input must fail, and must say which field is wrong.
        rejects-bad-input = pkgs.runCommand "ipkg-render-rejects-bad-input" {
          nativeBuildInputs = [
            renderer
            pkgs.gnugrep
          ];
        } ''
          if ipkg-render < ${../tests/bad-version.json} > /dev/null 2> err.txt; then
            echo "expected a failure for a version that is a string"
            exit 1
          fi
          grep -q 'Error in \$.version' err.txt
          touch $out
        '';
      };
    };
}
