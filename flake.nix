{
  description = "GitHub-style Markdown to PDF";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in
  {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        pandoc
        chromium
      ];
    };

    apps.${system}.default = {
      type = "app";

      program = toString (pkgs.writeShellScript "md2pdf" ''
        set -euo pipefail

        if [ $# -ne 1 ]; then
          echo "Usage: md2pdf <file.md>"
          exit 1
        fi

        INPUT="$1"

        NAME="$(basename "$INPUT" .md)"
        DIR="$(dirname "$INPUT")"

        TMP_HTML="$(mktemp --suffix=.html)"

        ${pkgs.pandoc}/bin/pandoc \
          -f gfm \
          -s \
          --toc \
          --toc-depth=3 \
          --highlight-style=pygments \
          --template=${./template.html} \
          "$INPUT" \
          -o "$TMP_HTML"

        ${pkgs.chromium}/bin/chromium \
          --headless \
          --disable-gpu \
          --no-pdf-header-footer \
          --print-to-pdf="$DIR/$NAME.pdf" \
          "file://$TMP_HTML"

        rm -f "$TMP_HTML"

        echo "Generated $DIR/$NAME.pdf"
      '');
    };
  };
}
