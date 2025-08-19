{
  # This description helps others understand the purpose of this Flake
  description = "A UV flake skeleton";

  # Inputs are the dependencies for our Flake
  # They're pinned to specific versions to ensure reproducibility
  inputs = {
    # nixpkgs is the main repository of Nix packages
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # flake-utils provides helpful functions for working with Flakes
    flake-utils.url = "github:numtide/flake-utils";
  };

  # Outputs define what our Flake produces
  # In this case, it's a development shell that works across different systems
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # We're creating a custom instance of nixpkgs
        # This allows us to enable unfree packages like CUDA
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;  # This is necessary for CUDA support
          };
        };

        # These helpers let us adjust our setup based on the OS
        isDarwin = pkgs.stdenv.isDarwin;
        isLinux = pkgs.stdenv.isLinux;

        # Common packages that we want available in our environment
        # regardless of the operating system
        commonPackages = with pkgs; [
          python312      # Python 3.13 interpreter
          uv             # Modern Python dependency manager replacing virtualenv and pip
          zlib           # Compression library for data compression
          git            # Version control system for tracking changes
          curl           # Command-line tool for transferring data with URLs
        ] ++ (with pkgs; pkgs.lib.optionals isLinux [
          gcc            # GNU Compiler Collection for compiling C/C++ code
          stdenv.cc.cc.lib  # Standard C library for Linux systems
        ]);

        # This script sets up our Python environment and project
        runScript = pkgs.writeShellScriptBin "run-script" ''
          #!/usr/bin/env bash

          # Activate the virtual environment
          source .venv/bin/activate
        '';

        # Base shell hook that just sets up the environment without any output
        baseEnvSetup = pkgs: ''
          # Set up the Python virtual environment with uv
          test -d .venv || ${pkgs.uv}/bin/uv venv .venv
          export VIRTUAL_ENV="$(pwd)/.venv"
          export PATH="$VIRTUAL_ENV/bin:$PATH"
          export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath commonPackages}:$LD_LIBRARY_PATH
        '';

        # Function to create shells for each OS
        mkLinuxShells = pkgs: {
          # Default shell with the full interactive setup for human use
          default = pkgs.mkShell {
            buildInputs = commonPackages;
            shellHook = ''
              ${baseEnvSetup pkgs}

              # Run the full interactive script
              ${runScript}/bin/run-script
            '';
          };

          # Quiet shell for AI assistants, automation and scripting
          quiet = pkgs.mkShell {
            buildInputs = commonPackages;
            shellHook = ''
              ${baseEnvSetup pkgs}
              # Minimal confirmation message
              echo "Quiet Nix environment activated."
            '';
          };
        };

        # Function to create Darwin/macOS shells
        mkDarwinShells = pkgs: {
          # Default shell with the full interactive setup for human use
          default = pkgs.mkShell {
            buildInputs = commonPackages;
            shellHook = ''
              ${baseEnvSetup pkgs}

              # Run the full interactive script
              ${runScript}/bin/run-script
            '';
          };

          # Quiet shell for AI assistants, automation and scripting
          quiet = pkgs.mkShell {
            buildInputs = commonPackages;
            shellHook = ''
              ${baseEnvSetup pkgs}
              # Minimal confirmation message
              echo "Quiet Nix environment activated."
            '';
          };
        };

        # Get the appropriate shells for the current OS
        shells = if isLinux then mkLinuxShells pkgs else mkDarwinShells pkgs;

      in {
        # Multiple devShells for different use cases
        devShells = shells;

        # The default devShell (when just running 'nix develop')
        devShell = shells.default;
      });
}
