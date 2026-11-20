{ inputs, ... }:
let
  helpers = import ../lib/mk-ipkg.nix { lib = inputs.nixpkgs.lib; };
in
{
  # System-independent helpers. Callers pass their own `pkgs` and the
  # `ipkg-render` for their system, so this flake never dictates a nixpkgs.
  flake.lib = {
    inherit (helpers) toPkgJson rules;

    # mkIpkg { inherit pkgs renderer; } ipkg -> derivation producing the .ipkg
    mkIpkg =
      { pkgs, renderer }:
      helpers.mkIpkg {
        inherit pkgs renderer;
      };

    # mkSrc { inherit pkgs renderer; } { inherit src ipkg; } -> src + injected .ipkg
    mkSrc =
      { pkgs, renderer }:
      helpers.mkSrc {
        inherit pkgs renderer;
      };
  };
}
