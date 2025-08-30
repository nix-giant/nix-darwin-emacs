/*
  Parse an emacs lisp configuration file to derive packages from
  use-package declarations.
*/

{ pkgs }:
let
  parse = pkgs.callPackage ./parse.nix { };
  inherit (pkgs) lib;
in
{
  config,
  # bool to use the value of config or a derivation whose name is default.el
  defaultInitFile ? false,
  # emulate `use-package-always-ensure` behavior (defaulting to false)
  alwaysEnsure ? false,
  # emulate `use-package-always-pin` behavior (defaulting to false)
  alwaysPin ? false,
  # emulate `#+PROPERTY: header-args:emacs-lisp :tangle yes`
  alwaysTangle ? false,
  extraEmacsPackages ? epkgs: [ ],
  package ? pkgs.emacs-unstable,
  override ? (self: super: { }),
}:
let
  configType = config: if (lib.strings.isStorePath config) then "path" else (builtins.typeOf config);

  isOrgModeFile =
    let
      ext = lib.last (builtins.split "\\." (builtins.toString config));
      type = configType config;
    in
    type == "path" && ext == "org";

  configText =
    let
      type = configType config;
    in
    if type == "string" then
      config
    else if type == "path" then
      builtins.readFile config
    else
      throw "Unsupported type for config: \"${type}\"";

  packages = parse.parsePackagesFromUsePackage {
    inherit
      configText
      isOrgModeFile
      alwaysTangle
      alwaysEnsure
      alwaysPin
      ;
  };
  emacsPackages = (pkgs.emacsPackagesFor package).overrideScope (
    self: super:
    # for backward compatibility: override was a function with one parameter
    if builtins.isFunction (override super) then override self super else override super
  );
  emacsWithPackages = emacsPackages.emacsWithPackages;
  mkPackageError =
    name: throw "Emacs package ${name}, declared wanted with use-package, not found." null;
in
emacsWithPackages (
  epkgs:
  let
    pkgArchives = {
      "gnu" = "elpaPackages";
      "gnu-devel" = "elpaDevelPackages";
      "nongnu" = "nongnuPackages";
      "nongnu-devel" = "nongnuDevelPackages";
      "melpa" = "melpaPackages";
      "melpa-stable" = "melpaStablePackages";
    };
    usePkgs = map (
      pkg:
      if pkg.archive != null then
        epkgs.${pkgArchives.${pkg.archive}}.${pkg.name}
          or (mkPackageError "${pkgArchives.${pkg.archive}}.${pkg.name}")
      else
        epkgs.${pkg.name} or (mkPackageError pkg.name)
    ) packages;
    extraPkgs = extraEmacsPackages epkgs;
    defaultInitFilePkg =
      if !((builtins.isBool defaultInitFile) || (lib.isDerivation defaultInitFile)) then
        throw "defaultInitFile must be bool or derivation"
      else if defaultInitFile == false then
        null
      else
        let
          # name of the default init file must be default.el according to elisp manual
          defaultInitFileName = "default.el";
        in
        epkgs.trivialBuild {
          pname = "default";
          src =
            if defaultInitFile == true then
              pkgs.writeText defaultInitFileName configText
            else if defaultInitFile.name == defaultInitFileName then
              defaultInitFile
            else
              throw "name of defaultInitFile must be ${defaultInitFileName}";
          version = "0.1.0";
          packageRequires = usePkgs ++ extraPkgs;
        };
  in
  usePkgs ++ extraPkgs ++ [ defaultInitFilePkg ]
)
