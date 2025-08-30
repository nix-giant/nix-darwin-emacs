{
  description = "A nix overlay for nearly stable Emacs on Darwin.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-24.05-darwin";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    {
      # self: super: must be named final: prev: for `nix flake check` to be happy
      overlays = {
        default = final: prev: import ./overlays/emacs.nix final prev;
        emacs = final: prev: import ./overlays/emacs.nix final prev;
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      (
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          packages.emacs-unstable = pkgs.emacs-unstable;
          packages.emacs-30 = pkgs.emacs-30;
          packages.emacs-29 = pkgs.emacs-29;

          packages.test-build-emacs = pkgs.callPackage ./test/build-emacs { };
        }
      )
    );
}
