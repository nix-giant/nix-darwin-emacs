{ pkgs, ... }:
pkgs.emacsWithPackagesFromUsePackage {
  config = ./config.el;
  package = pkgs.emacs-30;
}
