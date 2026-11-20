{ inputs, ... }:
{
  perSystem =
    { pkgs, system, config, ... }:
    let
      ps = inputs.packageset.packages.${system};
    in
    {
      checks = {
        build = config.packages.ipkg-render;

        # Golden test: render a fixture and diff it against the expected file.
        # The output is the compiler's `pretty`, so this also pins the formatting
        # and will fail if the compiler changes it.
        golden = pkgs.runCommand "ipkg-render-golden" {
          nativeBuildInputs = [
            config.packages.ipkg-render
            pkgs.diffutils
          ];
        } ''
          ipkg-render < ${../tests/fixture.json} > actual.ipkg
          diff -u ${../tests/expected.ipkg} actual.ipkg
          touch $out
        '';

        # A malformed input must fail, and must say which field is wrong.
        rejects-bad-input = pkgs.runCommand "ipkg-render-rejects-bad-input" {
          nativeBuildInputs = [
            config.packages.ipkg-render
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
