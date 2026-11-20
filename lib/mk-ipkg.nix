# Nix-side mapping from an ergonomic package declaration to a rendered .ipkg.
{ lib }:
rec {
  # --- rewrite rules: ergonomic declaration -> Idris.Package.Types.PkgDesc ---
  #
  # Each is one line and independent. If a compiler update renames or retypes a
  # field, the reflection-derived decoder in ipkg-render follows automatically
  # and at most one rule here needs editing; a stale rule fails naming the JSON
  # field. These are generic to any Idris package — they encode PkgDesc's shape,
  # not any particular project's.
  rules = {
    # "0.1.0" -> MkPkgVersion (0 ::: [1, 0])
    version = v: map lib.toInt (lib.splitString "." v);

    # any version is acceptable: PkgVersionBounds with no bounds
    anyBounds = {
      lowerBound = null;
      lowerInclusive = true;
      upperBound = null;
      upperInclusive = true;
    };

    # [ "eff" ] -> [ MkDepends "eff" anyBounds ]
    depends = map (d: {
      pkgname = d;
      pkgbounds = rules.anyBounds;
    });

    # [ "A.B" ] -> [ (MkMI ["A","B"], "A.B") ]; ipkg-render decodes the string
    # through mkNamespace, so only the filename needs pairing.
    modules = map (m: [
      m
      m
    ]);

    # "Chain" -> (MkMI ["Chain"], "Chain")
    main = m: [
      m
      m
    ];

    # "--total" -> Just (EmptyFC, "--total")
    options = o: [
      null
      o
    ];
  };

  # Field names on the left are PkgDesc's.
  toPkgJson =
    p:
    {
      name = p.package;
      version = rules.version p.version;
      authors = p.authors or null;
      maintainers = p.maintainers or null;
      license = p.license or null;
      brief = p.brief or null;
      readme = p.readme or null;
      homepage = p.homepage or null;
      sourcedir = p.sourcedir or null;
      executable = p.executable or null;
      depends = rules.depends (p.depends or [ ]);
      modules = rules.modules (p.modules or [ ]);
      mainmod = if (p.main or null) == null then null else rules.main p.main;
      options = if (p.opts or null) == null then null else rules.options p.opts;
    }
    // lib.genAttrs [
      "langversion"
      "sourceloc"
      "bugtracker"
      "datadir"
      "builddir"
      "outputdir"
      "prebuild"
      "postbuild"
      "preinstall"
      "postinstall"
      "preclean"
      "postclean"
    ] (_: null);

  # --- derivations -----------------------------------------------------------

  # `renderer` is the system's ipkg-render; `pkgs` supplies runCommand and
  # writeText. Both are baked in per system by nix/lib.nix.
  mkIpkg =
    { pkgs, renderer }:
    p:
    pkgs.runCommand "${p.package}.ipkg" { } ''
      ${renderer}/bin/ipkg-render < ${pkgs.writeText "${p.package}.json" (builtins.toJSON (toPkgJson p))} > $out
    '';

  # A copy of `src` with the rendered .ipkg injected, and any stale one removed.
  mkSrc =
    { pkgs, renderer }:
    { src, ipkg }:
    pkgs.runCommand "${ipkg.package}-src" { } ''
      mkdir -p $out
      cp -r ${src}/. $out/
      chmod -R u+w $out
      rm -f $out/*.ipkg
      cp ${mkIpkg { inherit pkgs renderer; } ipkg} $out/${ipkg.package}.ipkg
    '';
}
