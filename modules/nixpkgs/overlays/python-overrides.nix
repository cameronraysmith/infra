# Python package overrides
#
# Coupled because the python3 override and the python3Packages rebind must
# share a single override scope: the rebind `python3Packages = final.python3.pkgs`
# only sees the package set produced by this same override invocation.
#
# Future refactor: pygame and the duckdb cross-reference could migrate to
# `pythonPackagesExtensions ++ [ ... ]` (see modules/nixos/nvidia.nix), but
# the python3Packages rebind would still need to live somewhere — splitting
# further is out of scope here.
#
# Contained:#
#   - duckdb cross-reference: route python3Packages.duckdb through the by-name
#     python-duckdb package (pkgs/by-name/python-duckdb/), which has tests
#     disabled and tracks the by-name C++ duckdb version. On machines (via
#     compose.nix), final.python-duckdb exists because customPackages are
#     merged into the overlay scope. In perSystem context it doesn't exist,
#     so fall back to nixpkgs' version.
#     Update both packages: nix run .#update-duckdb
#     Machine shadowing is gated by modules/nixpkgs/duckdb-local.nix; when its
#     toggle withholds the pair, the `or pyPrev.duckdb` fallback routes through
#     nixpkgs everywhere.
#   - lancedb cross-reference: route python3Packages.lancedb through the by-name
#     python-lancedb package (pkgs/by-name/python-lancedb/), which tracks 0.36.0
#     because nixpkgs' 0.32.0 fails to compile; see that package for the ethnum
#     E0512 rationale and the removal trigger. Ungated, so the shadow applies on
#     every machine; the `or pyPrev.lancedb` fallback covers the perSystem
#     context where customPackages are absent.
{ ... }:
{
  nixpkgsOverlays = [
    (final: prev: {
      python3 = prev.python3.override {
        packageOverrides = pyFinal: pyPrev: {
          duckdb = final.python-duckdb or pyPrev.duckdb;
          lancedb = final.python-lancedb or pyPrev.lancedb;
        };
      };
      python3Packages = final.python3.pkgs;
    })
  ];
}
