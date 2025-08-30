self: super:
let
  mkEmacs =
    namePrefix: repoMetaFile: patches:
    { ... }@args:
    let
      repoMeta = super.lib.importJSON repoMetaFile;
      fetcher =
        if repoMeta.type == "savannah" then
          super.fetchFromSavannah
        else if repoMeta.type == "github" then
          super.fetchFromGitHub
        else
          throw "Unknown repo type ${repoMeta.type}";
    in
    builtins.foldl' (drv: fn: fn drv) super.emacs [
      (drv: drv.override ({ srcRepo = true; } // args))

      (
        drv:
        drv.overrideAttrs (old: {
          name = "${namePrefix}-${repoMeta.version}";
          inherit (repoMeta) version;
          src = fetcher (
            builtins.removeAttrs repoMeta [
              "type"
              "version"
              "branch"
            ]
          );

          patches = [ ];

          postPatch = old.postPatch + ''
            substituteInPlace lisp/loadup.el \
            --replace-fail '(emacs-repository-get-version)' '"${repoMeta.rev}"' \
            --replace-fail '(emacs-repository-get-branch)' '"${repoMeta.branch}"'
          '';
        })
      )

      # fix native compiler error
      (
        drv:
        drv.overrideAttrs (old: {
          postPatch =
            old.postPatch
            + (super.lib.optionalString ((old ? NATIVE_FULL_AOT) || (old ? env.NATIVE_FULL_AOT)) (
              let
                backendPath = (
                  super.lib.concatStringsSep " " (
                    builtins.map (x: ''\"-B${x}\"'') (
                      [
                        # Paths necessary so the JIT compiler finds its libraries:
                        "${super.lib.getLib self.libgccjit}/lib"
                        "${super.lib.getLib self.libgccjit}/lib/gcc"
                        "${super.lib.getLib self.stdenv.cc.libc}/lib"
                      ]
                      ++ super.lib.optionals (self.stdenv.cc ? cc.libgcc) [
                        "${super.lib.getLib self.stdenv.cc.cc.libgcc}/lib"
                      ]
                      ++ [
                        # Executable paths necessary for compilation (ld, as):
                        "${super.lib.getBin self.stdenv.cc.cc}/bin"
                        "${super.lib.getBin self.stdenv.cc.bintools}/bin"
                        "${super.lib.getBin self.stdenv.cc.bintools.bintools}/bin"
                      ]
                      ++ super.lib.optionals (self ? apple-sdk) [
                        # The linker needs to know where to find libSystem on Darwin.
                        "${self.apple-sdk.sdkroot}/usr/lib"
                      ]
                    )
                  )
                );
              in
              ''
                substituteInPlace lisp/emacs-lisp/comp.el --replace-fail \
                  "(defcustom comp-libgccjit-reproducer nil" \
                  "(setq native-comp-driver-options '(${backendPath}))
                   (defcustom comp-libgccjit-reproducer nil"
              ''
            ));
        })
      )

      # accept patches
      (
        drv:
        drv.overrideAttrs (old: {
          patches = old.patches ++ patches;
        })
      )

      # replace default icon
      (
        drv:
        drv.overrideAttrs (old: {
          postInstall = old.postInstall + ''
            cp ${./icons/Emacs.icns} $out/Applications/Emacs.app/Contents/Resources/Emacs.icns
          '';
        })
      )

      # make emacs package available on macOS only
      (
        drv:
        drv.overrideAttrs (old: {
          meta = old.meta // {
            platforms = super.lib.platforms.darwin;
          };
        })
      )

      # reconnect pkgs to the built emacs
      (
        drv:
        let
          result = drv.overrideAttrs (old: {
            passthru = old.passthru // {
              pkgs = self.emacsPackagesFor result;
            };
          });
        in
        result
      )
    ];
in
{
  emacs-unstable = mkEmacs "emacs-unstable" ../repos/emacs/unstable.json [
    # patches from https://github.com/d12frosted/homebrew-emacs-plus
    ./patches-unstable/system-appearance.patch
    ./patches-unstable/round-undecorated-frame.patch
  ] { };

  emacs-30 = mkEmacs "emacs-30" ../repos/emacs/30.json [
    # patches from https://github.com/d12frosted/homebrew-emacs-plus
    ./patches-30/fix-window-role.patch
    ./patches-30/system-appearance.patch
    ./patches-30/round-undecorated-frame.patch
  ] { };

  emacs-29 = mkEmacs "emacs-29" ../repos/emacs/29.json [
    # patches from https://github.com/d12frosted/homebrew-emacs-plus
    ./patches-29/fix-window-role.patch
    ./patches-29/system-appearance.patch
    ./patches-29/round-undecorated-frame.patch
  ] { };

  emacsWithPackagesFromUsePackage = import ../elisp.nix { pkgs = self; };

  emacsWithPackagesFromPackageRequires = import ../packreq.nix { pkgs = self; };
}
