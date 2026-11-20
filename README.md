# idris2-ipkg

Render Idris2 `.ipkg` files from JSON.

The point is not the JSON. The point is that **the field set, the ordering, the
formatting, and the decoding all come from the compiler**. `PkgDesc` is
deserialised by reflection and rendered with `Idris.Package.Types.pretty` — the
same code path `idris2 --init` uses — so an upstream change to the package-file
record is absorbed by the derivation instead of needing a matching edit here.

```console
$ ipkg-render < metadata.json > package.ipkg
```

## Why

A `.ipkg` is small but its shape is not stable across compiler versions, and
hand-writing a renderer or a decoder means maintaining a mirror of
`PkgDesc` that silently rots. Here the mirror is generated.

Only two instances are hand-written, for types the compiler does not let you
construct directly:

| type | why | what it does |
|---|---|---|
| `Core.FC.FC` | a source location has no JSON form | always `EmptyFC` |
| `ModuleIdent` | its constructor is private | decodes a dotted string via `mkNamespace` |

Everything else is:

```idris
%runElab derive "PkgVersion" [FromJSON]
%runElab derive "PkgVersionBounds" [FromJSON]
%runElab derive "Depends" [FromJSON]
%runElab derive "PkgDesc" [FromJSON]
```

## Input

The JSON is exactly `PkgDesc`'s record shape, because that is what the derived
decoder expects. The awkward corners are the compiler's, not this tool's:

| field | shape | note |
|---|---|---|
| `version` | `[0, 1, 0]` | `MkPkgVersion (List1 Nat)` |
| `depends` | `[{ "pkgname": "eff", "pkgbounds": { … } }]` | |
| `modules` | `[["Crypto", "Crypto"], …]` | ident/filename pairs |
| `mainmod` | `["Chain", "Chain"]` or `null` | |
| `options` | `[null, "--total"]` or `null` | an `FC` slot, then the flags |

`tests/fixture.json` is a complete example.

## Use as a flake input

```nix
{
  inputs.idris2-ipkg.url = "github:you/idris2-ipkg";

  outputs = { self, nixpkgs, idris2-ipkg, ... }:
    let
      system  = "x86_64-linux";
      pkgs    = nixpkgs.legacyPackages.${system};
      ipkg    = idris2-ipkg.packages.${system}.ipkg-render;
    in {
      packages.${system}.my-package = pkgs.runCommand "my-package.ipkg" { } ''
        ${ipkg}/bin/ipkg-render < ${./metadata.json} > $out
      '';
    };
}
```

## Mapping an ergonomic config onto it

Nothing forces you to author the shapes above by hand. Declare what you mean and
rewrite it — in Nix, next to the declaration, where the module system can
validate the input side:

```nix
rules = {
  version  = v: map lib.toInt (lib.splitString "." v);
  depends  = map (d: { pkgname = d; pkgbounds = anyBounds; });
  modules  = map (m: [ m m ]);
  main     = m: [ m m ];
  options  = o: [ null o ];
};
```

Each rule is one line and independent. If a compiler update renames or retypes a
field, the derivation follows automatically and at most one rule needs editing.
A stale rule fails loudly, naming the field:

```
ipkg-render: Error in $.version: parsing List1 failed, expected Array,
but encountered String
```

## Notes for maintainers

- **Reading stdin, not argv.** `getContents` is absent in Idris 2, and `readFile`
  reaches `Data.Fuel.forever`, which fails under `--total`. Stdin is the
  dependable interface.
- **Qualify `FC` and `ModuleIdent`.** Importing `Derive.FromJSON` /
  `Derive.Prelude` brings `Language.Reflection.TT.FC` and `…TT.ModuleIdent` into
  scope. They shadow the compiler's types, and the resulting error is
  misleading — it looks like a missing `FromJSON` instance for
  `List (ModuleIdent, String)` rather than a name clash.
- **The compiler's package is installed as `idris2`**, not `idris2api`, whatever
  the nixpkgs attribute is called.
- **`json` is not the compiler's JSON.** The compiler's own `ToJson` is a
  private, one-off serializer with no string escaping and no decoder; this uses
  the `json` package from the pack-db, which has a derived decoder.

## Building

```sh
nix build                 # ./result/bin/ipkg-render
nix flake check           # build, golden test, bad-input rejection
nix develop
```

Dependencies (`idris2`'s package and `json`) come from
[nix-idris2-packages](https://github.com/mattpolzin/nix-idris2-packages), so each
is its own derivation and builds without network access.

## Licence

MIT — see [LICENSE](LICENSE). Chosen over copyleft because this is a small
tool, and over Apache-2.0 because MIT imposes no NOTICE-file duties and stays
compatible with GPL-2.0-only downstreams.
