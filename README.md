# idris2-ipkg

## AI Usage Badge

|![0rwx: W — AI has read-write access; AI collaboration](https://raw.githubusercontent.com/NamtaoProductions/0rwx.com/refs/heads/main/static/50x50/AI-W-50x50.png) | [0rwx: W — AI has read-write access; AI collaboration](https://0rwx.com/) |
|---|---|

More information at the bottom

## Description

Render Idris2 `.ipkg` files from JSON.

The point is not the JSON. The point is that **the field set, the
ordering, the formatting, and the decoding all come from the
compiler**. `PkgDesc` is deserialised by reflection and rendered with
`Idris.Package.Types.pretty` — the same code path `idris2 --init` uses
— so an upstream change to the package-file record is absorbed by the
consumer instead of needing a matching edit here.

```console
$ ipkg-render < metadata.json > package.ipkg
```

## Motivation

This project was borne out of frustration from using
[Idris2](https://github.com/idris-lang/Idris2),
[Pack](https://github.com/stefan-hoeck/idris2-pack), and
[Nix](https://nixos.org/) together.

The Idris2 ecosystem is overwhelmingly packaged, at least nowadays,
using Pack.

This means that any project that wants to use most Idris2 libraries
nowadays has to use Pack at some point, or at least be able to parse an
`.ipkg` file.

This is often at odds with Nix's deterministic locking and fetching,
since Pack's locks are:
- Compiler-dependent, so the same package (NOT derivation!), cannot be
  reliably locked across machines with different architectures
- `$PACK_DIR`-wide, so special isolation is needed to lock project-wide
- Not reproducible using Pack itself

So, to reconcile these, I was left with several less-than-optimal
options:

- Lock the entire dependency closure, using an FOD, and running Pack
  inside
  - This has the benefit of working, but per-package caching is a no-go
- Use [`idr2nix`](https://sr.ht/~thatonelutenist/idr2nix/)
  - While this (may?) work, this project has been unmaintained for
    quite a while
- Use [`nix-idris2-packages`](https://github.com/mattpolzin/nix-idris2-packages)
  - While this is amazing, and ultimately what I go with, it completely
    trashes any compatibility with the pack ecosystem, since the
    dependencies are now specified in the Nix expression, not in the
    `.ipkg`

What is the solution for this?

Well, given the context of Nix projects like
[flake-file](https://github.com/denful/flake-file), it's quite simple:

Generate the .ipkg file from Nix code!

Now, there is no stable `.ipkg` parsing and serializing library, so I
just made my own.

Having just complained about unmaintainability, you might be puzzled:
How could this make any sense from a *maintainability* perspective?

While we don't have a serializer and deserializer, we do have a
wonderful package for
[`json`](https://github.com/stefan-hoeck/idris2-json) support, and the
compiler's parser, which is written in a language with wondrous
reflection support, and excellently detailed typing.

So bad those two things could not be combined in any way whatsoever.

...

Oh Wait!

## Why Derive the (De)Serializers, and How

A `.ipkg` is small but its shape is not stable across compiler
versions, and hand-writing a renderer or a decoder means maintaining a
mirror of `PkgDesc` that silently rots. Here the mirror is generated.

Only two instances are hand-written, for types the compiler does not
let you construct directly:

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

The JSON is exactly `PkgDesc`'s record shape, because that is what the
derived decoder expects. The awkward corners are the compiler's, not
this tool's:

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

## Or: from a Nix declaration

`lib.mkIpkg` takes the ergonomic declaration, applies the rewrite
rules, and produces the rendered file:

```nix
let
  ipkgFor = inputs.idris2-ipkg.lib.mkIpkg {
    inherit pkgs;
    renderer = inputs.idris2-ipkg.packages.${system}.ipkg-render;
  };

  myIpkg = ipkgFor {
    package   = "my-package";
    version   = "0.1.0";
    sourcedir = "src";
    depends   = [ "eff" ];
    opts      = "--total";
    modules   = [ "My.Module" ];
  };
in {
  packages.${system}.my-package = pkgs.runCommand "my-package.ipkg" { } ''
    cp ${myIpkg} $out
  '';
}
```

`lib.mkSrc { inherit pkgs renderer; } { inherit src ipkg; }` renders
the file and injects it into a copy of `src`, removing any stale
`.ipkg` — the shape you want for a build source.

`lib.rules` and `lib.toPkgJson` are exposed so a consumer can inspect
or override the mapping.

The helpers are system-independent: you pass your own `pkgs` and the
renderer for your system, so this flake never imposes a
[nixpkgs](https://github.com/NixOS/nixpkgs) on you.

## Mapping an ergonomic config onto it

Nothing forces you to author the shapes above by hand. Declare what
you mean and rewrite it — in Nix, next to the declaration, where the
module system can validate the input side:

```nix
rules = {
  version  = v: map lib.toInt (lib.splitString "." v);
  depends  = map (d: { pkgname = d; pkgbounds = anyBounds; });
  modules  = map (m: [ m m ]);
  main     = m: [ m m ];
  options  = o: [ null o ];
};
```

Each rule is one line and independent. If a compiler update renames or
retypes a field, the derivation follows automatically and at most one
rule needs editing.
A stale rule fails loudly, naming the field:

```
ipkg-render: Error in $.version: parsing List1 failed, expected Array,
but encountered String
```

## Notes for maintainers

- **Reading stdin, not argv.** `getContents` is absent in Idris 2, and
  `readFile` reaches `Data.Fuel.forever`, which fails under `--total`.
  Stdin is the dependable interface.
- **Qualify `FC` and `ModuleIdent`.** Importing `Derive.FromJSON` /
  `Derive.Prelude` brings `Language.Reflection.TT.FC` and
  `…TT.ModuleIdent` into scope. They shadow the compiler's types, and
  the resulting error is misleading — it looks like a missing
  `FromJSON` instance for `List (ModuleIdent, String)` rather than a
  name clash.
- **The compiler's package is installed as `idris2`**, not `idris2api`,
  whatever the nixpkgs attribute is called.
- **`json` is not the compiler's JSON.** The compiler's own `ToJson`
  is a private, one-off serializer with no string escaping and no
  decoder; this uses the `json` package from the pack-db, whose
  `Derive.FromJSON` is built on
  [`elab-util`](https://github.com/stefan-hoeck/idris2-elab-util).

## Building

```sh
nix build                 # ./result/bin/ipkg-render
nix flake check           # build, golden test, bad-input rejection
nix develop
```

Dependencies (`idris2`'s package and `json`) come from
[nix-idris2-packages](https://github.com/mattpolzin/nix-idris2-packages),
so each is its own derivation and builds without network access when
cached.

The flake itself is assembled with
[flake-parts](https://github.com/hercules-ci/flake-parts) and
[import-tree](https://github.com/denful/import-tree);
[flake-file](https://github.com/denful/flake-file) is declared so
`flake.nix` can eventually be regenerated from the modules.

## Layout

```
flake.nix                 flake-parts + import-tree (+ flake-file declared)
nix/packages.nix          ipkg-render via buildIdris (idris2Api + packdb.json)
nix/lib.nix               exports lib.{mkIpkg,mkSrc,toPkgJson,rules}
nix/checks.nix            build, golden, lib-renders, rejects-bad-input
lib/mk-ipkg.nix           the rewrite rules and the derivations
src/Main.idr              the tool: 2 instances + 4 derives + pretty
tests/                    fixture, expected output, bad input
```

## AI usage

This repository is rated [`w`](https://0rwx.com) on the 0rwx scale —
*AI has read-write permissions*, which that framework calls
**AI collaboration**:

> W — WRITE — AI has read-write permissions — AI collaboration — I read the code

In practice the code here was written by an AI agent working from a
human-set design: the split between `pretty` and the decoder, the two
hand-written instances, the rule list, and the packaging were decided
in dialogue, and the agent implemented and verified them. The human
reviews and maintains.

The badge art is CC0, by
[NamtaoProductions](https://github.com/NamtaoProductions/0rwx.com).

## Licence

MIT — see [LICENSE](LICENSE). Chosen over copyleft because this is a
small tool, and over Apache-2.0 because MIT imposes no NOTICE-file
duties and stays compatible with GPL-2.0-only downstreams.
