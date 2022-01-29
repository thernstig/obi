#!/bin/sh

set -e

# Currently supported packages
# TODO Use arguments to decide which binaries to use
BINARIES="fzf exa"
GITHUB_REPO_PATH="junegunn/fzf ogham/exa"

# Make sure we can reach github
curl -sSf https://github.com/ > /dev/null

BINDIR=${BINDIR:-~/bin}
KERNEL_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
FORMAT="tar.gz" # TODO - Automat

tmpdir=$(mktemp -d)
trap 'rm -rf ${tmpdir}' EXIT

main() {
    echo "Host kernel name: $KERNEL_NAME"
    echo "Host architecture: $ARCH"

    rename_me "$BINARIES" "$GITHUB_REPO_PATH"
}

rename_me() {
    bins="$1"
    repos="$2"
    # Re-assign the function parameter $1 into multiple positional parameters,
    # split on the white space in the $1 parameter to the function call
    set -- $bins
    while [ -n "$1" ]; do
        bin=$1
        shift
        bins=$@
        set -- $repos
        repo=$1
        shift
        repos=$@
        set -- $bins

        # Get the current and latest version of a specific program (binary)
        current_version=
        if command -V "$bin" > /dev/null 2>&1; then
            current_version=$(current_version_"$bin")
        fi
        latest_version=$(latest_version "$repo")
        echo "$bin current version: $current_version"
        echo "$bin latest version: $latest_version"

        if [ "$current_version" = "$latest_version" ]; then
            echo "$bin is up to date"
        else
            # Download binary
            binary_download_name=$(binary_download_name_"$bin" "$latest_version")

            url="https://github.com/$repo/releases/download/$latest_version/$binary_download_name"
            echo "$url"
            http_download "${tmpdir}/${binary_download_name}" "${url}" || exit 1
            ls -l "${tmpdir}"

            (cd "${tmpdir}" && untar "${binary_download_name}")
            ls -l "${tmpdir}"

            # install binary
            test ! -d "${BINDIR}" && install -d "${BINDIR}"
            install "${tmpdir}/${bin}" "${BINDIR}/"
            echo "installed ${BINDIR}/${bin}"
        fi
    done
}

current_version_fzf() {
    fzf --version | cut -d' ' -f1
}

binary_download_name_fzf() {
    os="${KERNEL_NAME}"
    format="${FORMAT}"
    arch="${ARCH}"

	case "${os}" in
	cygwin_nt*) os="windows"; format="zip" ;;
	mingw*) os="windows"; format="zip" ;;
	msys_nt*) os="windows"; format="zip" ;;
	darwin*) format="zip" ;;
	esac

	case "${arch}" in
	aarch64) arch="arm64" ;;
	x86_64) arch="amd64" ;;
	esac

	echo "fzf-$1-${os}_${arch}.${format}"
}

latest_version() {
    latest_url="https://api.github.com/repos/$1/releases/latest"
    (curl -s "$latest_url" | tr -s '\n' ' ' | sed 's/.*tag_name": "//' | sed 's/".*//')
}

http_get() {
	tmpfile=$(mktemp)
	http_download "${tmpfile}" "$1" "$2" || return 1
	body=$(cat "${tmpfile}")
	rm -f "${tmpfile}"
	echo "${body}"
}

http_download_curl() {
	local_file=$1
	source_url=$2
	header=$3
	if [ -z "${header}" ]; then
		code=$(curl -w '%{http_code}' -sL -o "${local_file}" "${source_url}")
	else
		code=$(curl -w '%{http_code}' -sL -H "${header}" -o "${local_file}" "${source_url}")
	fi
	if [ "${code}" != "200" ]; then
		echo "http_download_curl received HTTP status ${code}"
		return 1
	fi
	return 0
}

http_download_wget() {
	local_file=$1
	source_url=$2
	header=$3
	if [ -z "${header}" ]; then
		wget -q -O "${local_file}" "${source_url}" || return 1
	else
		wget -q --header "${header}" -O "${local_file}" "${source_url}" || return 1
	fi
}

http_download() {
	if is_command curl; then
		http_download_curl "$@" || return 1
		return
	elif is_command wget; then
		http_download_wget "$@" || return 1
		return
	fi
	echo "http_download unable to find wget or curl"
	return 1
}

untar() {
	tarball=$1
	case "${tarball}" in
	*.tar.gz | *.tgz) tar -xzf "${tarball}" --warning=no-timestamp ;;
	*.tar) tar -xf "${tarball}" --warning=no-timestamp ;;
	*.zip) unzip "${tarball}" ;;
	*)
		echo "untar unknown archive format for ${tarball}"
		return 1
		;;
	esac
}

is_command() {
	command -v "$1" >/dev/null
}

main "$@"



# TODO

current_version_exa() {
    exa --version | cut -d' ' -f2
}

binary_download_name_exa() {
    echo $1 $2
}

current_version_rg() {
    rg -V | cut -d' ' -f2
}

binary_download_name_chezmoi() {
	case "${KERNEL_NAME}" in
	cygwin_nt*) os="windows" ;;
	mingw*) os="windows" ;;
	msys_nt*) os="windows" ;;
	*) os="${KERNEL_NAME}" ;;
	esac

	case "${ARCH}" in
	386) arch="i386" ;;
	aarch64) arch="arm64" ;;
	armv*) arch="arm" ;;
	i386) arch="i386" ;;
	i686) arch="i386" ;;
	x86) arch="i386" ;;
	x86_64) arch="amd64" ;;
	*) arch="${ARCH}" ;;
	esac

    # TODO FIX
	echo "fzf-$1-${os}_${arch}.zip"
}
