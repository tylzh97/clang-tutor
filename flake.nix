{
  description = "A Nix flake for banach-space/clang-tutor project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Use LLVM 19 packages
        llvm = pkgs.llvm_19;
        clang = pkgs.clang_19;
        
        # Python environment with lit
        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          lit
        ]);

        # Build environment
        buildInputs = with pkgs; [
          # Core LLVM/Clang dependencies
          llvm
          clang
          llvm_19.dev
          libclang
          
          # Build tools
          cmake
          ninja
          gnumake
          
          # Python with lit for testing
          pythonEnv
          
          # Additional tools that might be needed
          pkg-config
          
          # Standard development tools
          gcc
          gdb
        ];

        # Shell environment
        shellHook = ''
          NIX_PATH_ONLY=$(echo $PATH | tr ':' '\n' | grep -E '/nix/store' | tr '\n' ':')
          export PATH=$NIX_PATH_ONLY
          export PATH=$PATH:${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gnugrep}/bin
          PS1='\n\[\033[1;32m\][nix-shell:\w]\[\033[0m\]\n\$ '

          # Set up environment variables
          export Clang_DIR="${clang}"
          export CLANG_TUTOR_DIR="$PWD"
          
          # Add LLVM tools to PATH
          export PATH="${llvm}/bin:${clang}/bin:$PATH"
          
          # Set up CMake to find LLVM
          export CMAKE_PREFIX_PATH="${llvm}:${clang}:$CMAKE_PREFIX_PATH"
          
          # Print environment info
          echo "=== Clang Tutor Development Environment ==="
          echo "Clang version: $(clang --version | head -1)"
          echo "LLVM version: $(llvm-config --version)"
          echo "Clang_DIR: $Clang_DIR"
          echo "CLANG_TUTOR_DIR: $CLANG_TUTOR_DIR"
          echo "lit available: $(which lit)"
          echo "FileCheck available: $(which FileCheck)"
          echo ""
          echo "To build the project:"
          echo "  mkdir -p build && cd build"
          echo "  cmake -DCT_Clang_INSTALL_DIR=\$Clang_DIR -G Ninja .."
          echo "  ninja"
          echo ""
          echo "To run tests:"
          echo "  lit -vvv test/"
          echo "=========================================="
        '';

      in
      {
        # Development shell
        devShells.default = pkgs.mkShell {
          inherit buildInputs shellHook;
          
          # Additional environment variables
          CT_Clang_INSTALL_DIR = "${clang}";
          LLVM_DIR = "${llvm}";
        };

        # Package definition for the clang-tutor project
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "clang-tutor";
          version = "0.1.0";
          
          src = ./.;
          
          nativeBuildInputs = with pkgs; [
            cmake
            ninja
            pythonEnv
          ];
          
          buildInputs = with pkgs; [
            llvm_19.dev
            clang_19
            libclang
          ];
          
          # Configure phase
          configurePhase = ''
            runHook preConfigure
            
            mkdir -p build
            cd build
            
            cmake -G Ninja ..
            
            runHook postConfigure
          '';
          
          # Build phase
          buildPhase = ''
            runHook preBuild
            ninja
            runHook postBuild
          '';
          
          # Install phase
          installPhase = ''
            runHook preInstall
            
            mkdir -p $out/lib $out/bin
            
            # Copy built libraries
            find . -name "*.so" -exec cp {} $out/lib/ \;
            
            # Copy any executables
            find . -type f -executable -exec cp {} $out/bin/ \; 2>/dev/null || true
            
            runHook postInstall
          '';
          
          # Check phase for running tests
          doCheck = true;
          checkPhase = ''
            runHook preCheck
            
            # Run lit tests
            lit -vvv test/
            
            runHook postCheck
          '';
          
          meta = with pkgs.lib; {
            description = "A collection of out-of-tree Clang plugins for teaching and learning";
            homepage = "https://github.com/banach-space/clang-tutor";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.linux ++ platforms.darwin;
          };
        };

        # Apps for easy access
        apps = {
          # Build the project
          build = flake-utils.lib.mkApp {
            drv = pkgs.writeShellScriptBin "build-clang-tutor" ''
              set -e
              mkdir -p build
              cd build
              cmake -DCT_Clang_INSTALL_DIR=${clang} -G Ninja ..
              ninja
            '';
          };
          
          # Run tests
          test = flake-utils.lib.mkApp {
            drv = pkgs.writeShellScriptBin "test-clang-tutor" ''
              set -e
              export PATH="${llvm}/bin:${clang}/bin:$PATH"
              if [ ! -d "build" ]; then
                echo "Build directory not found. Run 'nix run .#build' first."
                exit 1
              fi
              cd build
              lit -vvv ../test/
            '';
          };
        };
      });
}
