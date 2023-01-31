#!/usr/bin/env bash

# Colors
# shellcheck disable=SC2034
Black='\e[0;30m'  # Black
Red='\e[0;31m'    # Red
Green='\e[0;32m'  # Green
Yellow='\e[0;33m' # Yellow
Blue='\e[0;34m'   # Blue
Purple='\e[0;35m' # Purple
Cyan='\e[0;36m'   # Cyan
# shellcheck disable=SC2034
White='\e[0;37m' # White
Reset='\e[0m'    # Text Reset

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DIR="$SCRIPT_DIR/tmp"

# Program settings
IMAGE="$1"
TAG="$2"

if ! command -v skopeo &>/dev/null; then
	$echo -ne "${Red}skopeo is not installed${Reset}\n"
	exit 1
fi
if ! command -v rclone &>/dev/null; then
	$echo -ne "${Red}rclone is not installed${Reset}\n"
	exit 1
fi
if ! command -v jq &>/dev/null; then
	$echo -ne "${Red}jq is not installed${Reset}\n"
	exit 1
fi
# If gecho is installed, use it
if command -v gecho &>/dev/null; then
    # shellcheck disable=SC2034
    echo="gecho"
else
    # shellcheck disable=SC2034
    echo="echo"
fi

if [ -z "$IMAGE" ] || [ -z "$TAG" ]; then
	$echo -ne "Usage: ${Yellow}$0${Reset} ${Cyan}<image> <tag>${Reset}\n"
	# shellcheck disable=SC2059
	printf "\t${Cyan}image${Reset} ${Blue}(string)${Reset}\t The name of the image to build\n"
	# shellcheck disable=SC2059
	printf "\t${Cyan}tag${Reset} ${Blue}(string)${Reset}\t The tag of the image to build\n"
	# Example in grey color
	$echo -ne "Example: ${Yellow}$0${Reset} ${Cyan}myimage latest${Reset}\n"
	exit 1
fi

if [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
	$echo -ne "${Red}CLOUDFLARE_ACCOUNT_ID is not set${Reset}\n"
	exit 1
fi
if [ -z "$R2_BUCKET" ]; then
	$echo -ne "${Red}R2_BUCKET is not set${Reset}\n"
	exit 1
fi
if [ -z "$R2_ACCESS_KEY_ID" ]; then
	$echo -ne "${Red}R2_ACCESS_KEY_ID is not set${Reset}\n"
	exit 1
fi
if [ -z "$R2_SECRET_ACCESS_KEY" ]; then
	$echo -ne "${Red}R2_SECRET_ACCESS_KEY is not set${Reset}\n"
	exit 1
fi

# Prepare
if [ -d "$DIR" ]; then
    rm -rf "$DIR"
fi
if [ -d "$SCRIPT_DIR"/v2 ]; then
    rm -rf "$SCRIPT_DIR"/v2
fi
if [ -f "$SCRIPT_DIR"/rclone.conf ]; then
    rm -f "$SCRIPT_DIR"/rclone.conf
fi

# Convert image to OCI format
$echo -ne "${Yellow}Converting image${Reset}\n"
skopeo copy --all "docker-daemon:$IMAGE:$TAG" "dir:$DIR"
$echo -ne "${Green}Converting completed${Reset}\n"

# Create rclone config
cat <<EOF >"$SCRIPT_DIR"/rclone.conf
[r2-registry]
type = s3
provider = Cloudflare
env_auth = false
access_key_id = $R2_ACCESS_KEY_ID
secret_access_key = $R2_SECRET_ACCESS_KEY
endpoint = https://$CLOUDFLARE_ACCOUNT_ID.r2.cloudflarestorage.com
EOF

shamove() {
	SHA=$(sha256sum "$1" | cut -d" " -f1)
	mv "$1" v2/"$IMAGE"/"$2"/sha256:"$SHA"
}

mkdir -p v2/"$IMAGE"/manifests v2/"$IMAGE"/blobs

# Move files to correct location
for FILE in "$DIR"/*; do
	case $FILE in
	*/version)
		rm "$FILE"
		;;
	*.manifest.json)
		shamove "$FILE" manifests
		;;
	*/manifest.json)
		cp "$FILE" v2/"$IMAGE"/manifests/"$TAG"
		shamove "$FILE" manifests
		;;
	*)
		shamove "$FILE" blobs
		;;
	esac
done

# List buckets silently via rclone (for debugging)
$echo -ne "${Yellow}Verifying bucket connection${Reset}\n"
rclone --config "$SCRIPT_DIR"/rclone.conf lsjson r2-registry:/"$R2_BUCKET" | jq -r '.[].Path' 2>/dev/null 1>&2 | exit 1
$echo -ne "${Green}Bucket connection verified${Reset}\n"

# Upload blobs
$echo -ne "${Yellow}Uploading blobs to bucket ${Cyan}$R2_BUCKET${Reset}\n"
rclone --config "$SCRIPT_DIR"/rclone.conf copy -P --s3-acl public-read --exclude '*/manifests/*' "$SCRIPT_DIR"/v2 r2-registry:/"$R2_BUCKET"/v2
$echo -ne "${Green}Upload completed${Reset}\n"

# Upload manifests
$echo -ne "${Yellow}Uploading manifests to bucket ${Cyan}$R2_BUCKET${Reset}\n"
find v2 -path '*/manifests/*' -print0 | while IFS= read -r -d '' MANIFEST; do
	CONTENT_TYPE=$(jq -r .mediaType <"$MANIFEST")
	if [ "$CONTENT_TYPE" = "null" ]; then
		CONTENT_TYPE="application/vnd.docker.distribution.manifest.v1+prettyjws"
	fi
	rclone --config "$SCRIPT_DIR"/rclone.conf copy -P --s3-acl public-read --header-upload "Content-Type: $CONTENT_TYPE" "$MANIFEST" r2-registry:/"$R2_BUCKET"/v2/"$IMAGE"/manifests/
done
$echo -ne "${Green}Upload completed${Reset}\n"

# Cleanup
$echo -ne "${Yellow}Cleaning up${Reset}\n"
rm -rf "$SCRIPT_DIR"/rclone.conf "$SCRIPT_DIR"/v2 "$SCRIPT_DIR"/tmp
$echo -ne "${Green}Cleanup completed${Reset}\n"

$echo -ne "${Green}Image uploaded successfully${Reset}\n"

# Print image URL if domain is set
if [ -n "$R2_DOMAIN" ]; then
	$echo -ne "${Yellow}Image URL: ${Cyan}$R2_DOMAIN/$IMAGE:$TAG${Reset}\n"
fi
