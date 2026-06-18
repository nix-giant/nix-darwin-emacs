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

      # filter out inapplicable patches
      (
        drv:
        drv.overrideAttrs (old: {
          patches =
            let
              isApplicable =
                patch:
                if super.lib.versionOlder old.version "31" then
                  true
                else
                  !(
                    builtins.elem patch.name or "" [
                      "fix-off-by-one-mistake-80851-CVE-2026-6861.patch"
                      "01_all_treesit-0.26.patch?id=d0f47979806d9be5a190fdb4ffa1bde439b2d616"
                      "02_all_ts-query-pred.patch?id=86190bf195b3e17108372d8ad89eb57037180dd2"
                    ]
                    || builtins.elem patch [
                      "/nix/store/jm6hjlhhy87gwyx6dk659qq7krpc3liw-inhibit-lexical-cookie-warning-67916.patch"
                    ]
                  );
            in
            builtins.filter isApplicable old.patches;
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

  emacs-31 = mkEmacs "emacs-31" ../repos/emacs/31.json [
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

  emacsWithPackagesFromPackageRequires = import ../lib/package-requires.nix { pkgs = self; };
  emacsWithPackagesFromUsePackage = import ../lib/use-package.nix { pkgs = self; };
}
