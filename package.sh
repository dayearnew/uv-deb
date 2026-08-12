#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_REPO="astral-sh/uv"
TAG="${1:?upstream tag is required}"
UPSTREAM_VERSION="${2:?upstream version is required}"
VERSION="${3:-${UPSTREAM_VERSION}}"
ARCH="${4:?Debian architecture is required}"
UPSTREAM_ARCH="${5:?upstream architecture is required}"
PACKAGE="$(awk '/^Package:/ { print $2; exit }' debian/control)"

write_control() {
  local arch="$1"
  local target="$2"
  awk -v version="${VERSION}" -v arch="${arch}" '
    /^Package:/ {
      print
      print "Version: " version
      print "Architecture: " arch
      next
    }
    { print }
  ' debian/control > "${target}"
}

rm -rf work dist
mkdir -p work dist

asset="uv-${UPSTREAM_ARCH}.tar.gz"
archive="work/${asset}"
extract_dir="work/extract-${ARCH}"
package_root="work/pkg-${ARCH}"

gh release download "${TAG}" --repo "${UPSTREAM_REPO}" --pattern "${asset}" --dir work --clobber
mkdir -p "${extract_dir}" "${package_root}/DEBIAN" "${package_root}/usr/bin"
tar -xzf "${archive}" -C "${extract_dir}"

uv_bin="$(find "${extract_dir}" -type f -name uv -print -quit)"
uvx_bin="$(find "${extract_dir}" -type f -name uvx -print -quit)"
test -n "${uv_bin}"
test -n "${uvx_bin}"
install -m 0755 "${uv_bin}" "${package_root}/usr/bin/uv"
install -m 0755 "${uvx_bin}" "${package_root}/usr/bin/uvx"

write_control "${ARCH}" "${package_root}/DEBIAN/control"

dpkg-deb --build --root-owner-group "${package_root}" "dist/${PACKAGE}_${VERSION}_${ARCH}.deb"

for deb in dist/*.deb; do
  dpkg-deb --info "${deb}" >/dev/null
done
