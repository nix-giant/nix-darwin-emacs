{ pkgs, ... }:
pkgs.emacsWithPackagesFromUsePackage {
  config = ./config.org;
  package = pkgs.emacs-30;
  alwaysTangle = true;
}
