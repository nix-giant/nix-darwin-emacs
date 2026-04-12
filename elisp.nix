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
  # use config as the default init file
  configAsDefaultInitFile ? false,
  # emulate `use-package-always-ensure` behavior
  alwaysEnsure ? false,
  # emulate `use-package-always-pin` behavior
  alwaysPin ? false,
  extraEmacsPackages ? epkgs: [ ],
  package ? pkgs.emacs-unstable,
  override ? (self: super: { }),
}:
let
  configType = config: if (lib.strings.isStorePath config) then "path" else (builtins.typeOf config);

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
      if configAsDefaultInitFile == true then
        let
          # the filename must be default.el according to elisp manual
          filename = "default.el";
        in
        epkgs.trivialBuild {
          pname = "default-init-file";
          version = "1";
          src = pkgs.writeText filename configText;
          packageRequires = usePkgs ++ extraPkgs;
        }

      else if configAsDefaultInitFile == false then
        null
      else
        throw "configAsDefaultInitFile must be bool";

  in
  usePkgs ++ extraPkgs ++ [ defaultInitFilePkg ]
)
