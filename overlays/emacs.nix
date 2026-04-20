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

          postPatch = old.postPatch + ''
            substituteInPlace lisp/loadup.el \
            --replace-fail '(emacs-repository-get-version)' '"${repoMeta.rev}"' \
            --replace-fail '(emacs-repository-get-branch)' '"${repoMeta.branch}"'
          '';
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

      # add EmacsClient.app
      (
        drv:
        drv.overrideAttrs (old: {
          postInstall =
            old.postInstall
            + (
              let
                info = super.lib.generators.toPlist { escape = true; } {
                  CFBundleExecutable = "EmacsClient";
                  CFBundleIdentifier = "org.gnu.EmacsClient";
                  CFBundleName = "EmacsClient";
                  CFBundleVersion = repoMeta.version;
                  CFBundleShortVersionString = repoMeta.version;
                  CFBundlePackageType = "APPL";
                  CFBundleIconFile = "EmacsClient.icns";
                };
              in
              ''
                ECAPP="$out/Applications/EmacsClient.app"
                mkdir -p $ECAPP

                mkdir -p "$ECAPP/Contents/MacOS"
                cat > "$ECAPP/Contents/MacOS/EmacsClient" <<EOF
                #!/bin/sh
                exec $out/bin/emacsclient --reuse-frame --alternate-editor="" "\$@" &>/dev/null 2>&1 &
                EOF
                chmod +x "$ECAPP/Contents/MacOS/EmacsClient"

                mkdir -p "$ECAPP/Contents/Resources"
                cp ${./icons/Emacs.icns} "$ECAPP/Contents/Resources/EmacsClient.icns"

                # create Info.plist
                cat > "$ECAPP/Contents/Info.plist" <<EOF
                ${info}
                EOF
              ''
            );
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
    ./patches-unstable/adjust-ns-init-colors.patch
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

  emacsWithPackagesFromPackageRequires = import ../lib/package-requires.nix { pkgs = self; };
  emacsWithPackagesFromUsePackage = import ../lib/use-package.nix { pkgs = self; };
}
