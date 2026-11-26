{
  description = "GitHub-style Markdown to PDF";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
      };

      fonts = pkgs.makeFontsConf { fontDirectories = [ pkgs.inter pkgs.jetbrains-mono pkgs.source-serif pkgs.dejavu_fonts ]; };

      md2pdf = pkgs.writeShellApplication {
        name = "md2pdf";

        runtimeInputs = with pkgs; [
          pandoc
          chromium
          (python3.withPackages (ps: [ ps.pypdf ps.reportlab ]))
          mermaid-cli
          coreutils
        ];

        text = ''
          export MD2PDF_FINISH="${./finish.py}"
          export MD2PDF_TEMPLATE="${./template.html}"
          export MD2PDF_STYLES="${./styles}"
          export MD2PDF_DESIGN_FILTER="${./filters/design.lua}"
          export MD2PDF_FONTCONFIG="${fonts}"
          export MD2PDF_CSS="${./github-markdown.min.css}"

          export MD2PDF_MERMAID_FILTER="${./mermaid.lua}"
          export PUPPETEER_EXECUTABLE_PATH="${pkgs.chromium}/bin/chromium"

          exec ${./run.sh} "$@"
        '';
      };
    in
    {
      apps.${system}.default = {
        type = "app";
        program = "${md2pdf}/bin/md2pdf";
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ md2pdf ];
      };
    };
}
