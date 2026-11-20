{
  description = "Render Idris2 .ipkg files from JSON, using the compiler's own pretty-printer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";
    flake-file.url = "github:denful/flake-file";

    # Idris2 compiler plus every pack-db library as a derivation. Deliberately
    # NOT following our nixpkgs: its binary cache is keyed to its own.
    packageset.url = "github:mattpolzin/nix-idris2-packages";
  };

  # Dendritic: every module under ./nix is imported by import-tree, and
  # flake-parts composes them. `flake-file` can regenerate this file from them.
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./nix);
}
