{ pkgs, ... }:
pkgs.emacsWithPackagesFromUsePackage {
  package = pkgs.emacs-30;
  config = ./config.el;
  configAsDefaultInitFile = true;
}
