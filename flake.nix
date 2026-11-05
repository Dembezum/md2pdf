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
    in
    {
      apps.${system}.default = {
        type = "app";
        program = toString (
          pkgs.writeShellScript "md2pdf" ''
            exec ${./run.sh} "$@"
          ''
        );
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          pandoc
          chromium
        ];
      };
    };
}
