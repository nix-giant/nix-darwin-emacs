{ pkgs, ... }:
pkgs.emacs-30.overrideAttrs (old: {
  postInstall =
    old.postInstall
    + (
      let
        info = pkgs.lib.generators.toPlist { escape = true; } {
          CFBundleExecutable = "EmacsClient";
          CFBundleIdentifier = "org.gnu.EmacsClient";
          CFBundleName = "EmacsClient";
          CFBundleVersion = old.version;
          CFBundleShortVersionString = old.version;
          CFBundlePackageType = "APPL";
          CFBundleIconFile = "EmacsClient.icns";
        };
      in
      ''
        EAPP="$out/Applications/Emacs.app"
        ECAPP="$out/Applications/EmacsClient.app"
        mkdir -p $ECAPP

        mkdir -p "$ECAPP/Contents/MacOS"
        cat > "$ECAPP/Contents/MacOS/EmacsClient" <<EOF
        #!/bin/sh
        # tip: change following line as you need
        exec $out/bin/emacsclient --alternate-editor= --create-frame "\$@" &>/dev/null 2>&1 &
        EOF
        chmod +x "$ECAPP/Contents/MacOS/EmacsClient"

        mkdir -p "$ECAPP/Contents/Resources"
        cp "$EAPP/Contents/Resources/Emacs.icns" "$ECAPP/Contents/Resources/EmacsClient.icns"

        # create Info.plist
        cat > "$ECAPP/Contents/Info.plist" <<EOF
        ${info}
        EOF
      ''
    );
})
