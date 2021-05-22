#!/bin/sh

set -e

# Currently supported packages
# TODO use arguments to decide which binaries to use
BINARIES="fzf"
GITHUB_REPO_PATH="junegunn/fzf"
# BINARIES="fzf exa"
# GITHUB_REPO_PATH="junegunn/fzf ogham/exa"

# Make sure we can reach github
curl -sSf https://github.com/ > /dev/null

BINDIR=${BINDIR:-~/bin}
KERNEL_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
FORMAT="tar.gz" # TODO automate finding out the format

tmpdir=$(mktemp -d)
trap 'rm -rf ${tmpdir}' EXIT

main() {
    bins="$BINARIES"
    repos="$GITHUB_REPO_PATH"

    # Sets the positional parameters e.g. if $bins is "fzf exa", then
    # the positional parameters becomes $1=fzf, $2=exa.
    # shellcheck disable=SC2086
    set -- $bins
    while [ -n "$1" ]; do
        bin=$1
        shift
        bins=$*
        # shellcheck disable=SC2086
        set -- $repos
        repo=$1
        shift
        repos=$*
        # shellcheck disable=SC2086
        set -- $bins

        # Get the current and latest version of a specific program (binary)
        if is_command "$bin"; then
            current_version=$(current_version_"$bin")
        fi
        latest_version=$(latest_version "$repo")
        echo "$bin version: current ($current_version) latest ($latest_version)"

        if [ "$current_version" = "$latest_version" ]; then
            echo "$bin is up to date"
        else
            # Download the archive
            # TODO add glibc and musl support
            download_name=$(download_name_"$bin" "$latest_version")
            url="https://github.com/$repo/releases/download/$latest_version/$download_name"
            echo "$url"
            http_download "${tmpdir}/${download_name}" "${url}" || exit 1

            # Unpack the archive
            (cd "${tmpdir}" && unpack "${download_name}")

            # Install the binary
            test ! -d "${BINDIR}" && install -d "${BINDIR}"
            install "${tmpdir}/${bin}" "${BINDIR}/"
            echo "installed ${BINDIR}/${bin}"
        fi
    done
}

### GENERIC FUNCTIONS ###

latest_version() {
    latest_url="https://api.github.com/repos/$1/releases/latest"
    (curl -s "$latest_url" | tr -s '\n' ' ' | sed 's/.*tag_name": "//' | sed 's/".*//')
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

unpack() {
	tarball=$1
	case "${tarball}" in
	*.tar.gz | *.tgz) tar -xzf "${tarball}" --warning=no-timestamp ;;
	*.tar) tar -xf "${tarball}" --warning=no-timestamp ;;
	*.zip) unzip "${tarball}" ;;
	*)
		echo "unpack unknown archive format for ${tarball}"
		return 1
		;;
	esac
}

is_command() {
	command -V "$1" > /dev/null 2>&1
}

### BINARY SPECIFIC FUNCTIONS ###

current_version_fzf() {
    fzf --version | cut -d' ' -f1
}

download_name_fzf() {
    os="${KERNEL_NAME}"
    arch="${ARCH}"
    format="${FORMAT}"

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

current_version_exa() {
    exa --version | cut -d' ' -f2
}

# TODO exa requires specific "install" instructions after unzipped,
# since it unpacks the binary into bin/exa
download_name_exa() {
    os="${KERNEL_NAME}"
    arch="${ARCH}"
    format="zip"

	case "${os}" in
	darwin*) os="macos" ;;
	esac

    # TODO Fix automatic musl support
    musl=
	echo "exa-${os}-${arch}${musl}-{$1}.${format}"
}

main "$@"


# TODO

current_version_rg() {
    rg -V | cut -d' ' -f2
}

download_name_chezmoi() {
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
