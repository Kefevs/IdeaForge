#!/usr/bin/env bash

# Script to pull container images with Podman and save as tar.xz files
# Usage:
#   ./save_images.sh [IMAGE_NAME...]
#   cat images.txt | ./save_images.sh

set -euo pipefail

# Logging functions
log() {
  echo "[INFO] $*" >&2
}

log_debug() {
  if [[ "${DEBUG:-}" == "true" ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

log_error() {
  echo "[ERROR] $*" >&2
}

usage() {
  cat <<EOF >&2
Usage: ${0##*/} [OPTIONS] [IMAGE_NAME...]

Pull container images using Podman and save each as a compressed tar.xz file.

Options:
  -h    Show this help message and exit
  -d    Enable debug logging

Examples:
  ${0##*/} registry.example.com/myimage:latest alpine:3.14
  cat myimages.txt | ${0##*/}
EOF
  exit 1
}

# Parse options
while getopts ":hd" opt; do
  case "$opt" in
    h) usage ;;  
    d) DEBUG=true ;;  
    *) usage ;;
  esac
done
shift $((OPTIND-1))

# Ensure Podman is available
if ! command -v podman &>/dev/null; then
  log_error "podman command not found. Please install Podman."
  exit 1
fi

# Determine input mode
read_from_stdin=false
if ! [ -t 0 ]; then
  log_debug "Reading image names from STDIN"
  read_from_stdin=true
fi

# Validate input
if [ "$#" -eq 0 ] && [ "$read_from_stdin" = false ]; then
  log_error "No container images specified."
  usage
fi

# Function to pull and save an image
process_image() {
  local img="$1"
  log "Processing image: $img"

  log_debug "Pulling $img"
  if ! podman pull "$img"; then
    log_error "Failed to pull $img"
    return 1
  fi

  # Create a safe filename
  local safe_name
  safe_name=$(echo "$img" | sed -E 's/[^a-zA-Z0-9._-]/_/g')
  local output_file="${safe_name}.tar.xz"

  log "Saving $img to $output_file"
  if podman save "$img" | xz -T0 > "$output_file"; then
    log "Successfully saved $img"
  else
    log_error "Failed to save $img"
    return 1
  fi
  echo
}

# Process CLI arguments
if [ "$#" -gt 0 ]; then
  for img in "$@"; do
    process_image "$img"
  done
fi

# Process STDIN if present
if [ "$read_from_stdin" = true ]; then
  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    process_image "$line"
  done
fi

