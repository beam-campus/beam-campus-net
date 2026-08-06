#!/usr/bin/env bash
# Build and publish the site image FROM HERE, when CI cannot.
#
# ⚠ THIS BYPASSES CI, WHICH IS NORMALLY THE GATE ON WHAT REACHES THE LIVE SITE.
# It exists for one situation: GitHub Actions is down and the fix is not.
#
# On 2026-08-06 Actions had a major outage from 15:22 UTC, throttling webhook
# delivery to ~15% — so three pushes to main recorded as PushEvents, produced no
# workflow run, and looked from a laptop exactly like a successful zero-touch
# deploy. The site sat on a nine-hour-old image while three commits described as
# "shipping" had never been built.
#
# ⚠⚠ RUN THE TESTS FIRST. CI is not just a builder, it is the thing that runs
# them on a clean machine. Skipping it means you are the clean machine:
#
#     cd system && touch apps/*/.formatter.exs && mix format --check-formatted \
#       && mix test
#
# The deploy path is otherwise unchanged: this pushes to ghcr and watchtower on
# the box pulls it within 60s, exactly as it would a CI build. What differs is
# who built it and that nothing independent checked it.
#
# ⚠⚠⚠ THE TOKEN IS NEVER ECHOED AND NEVER AN ARGUMENT. `gh auth token' writes to
# stdout, which goes straight into docker's stdin; an argument would be visible
# in `ps' to every user on the machine, and a here-string lands in shell history.
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE="${IMAGE:-ghcr.io/beam-campus/beam-campus-net}"
SHA="$(git rev-parse HEAD)"
SHORT="$(git rev-parse --short HEAD)"

if [ -n "$(git status --porcelain)" ]; then
    echo "!! working tree is dirty — the image would not match any commit" >&2
    git status --short >&2
    exit 65
fi

echo "[publish] $IMAGE  from $SHORT"
echo "[publish] ⚠ bypassing CI; tests must already be green locally"

gh auth token | docker login ghcr.io -u "$(gh api user --jq .login)" --password-stdin

# The same three tags CI applies on main, so watchtower and any rollback pin
# behave identically to a CI build.
docker build \
    -f Dockerfile.prod \
    --platform linux/amd64 \
    --build-arg "CACHE_BUST=${SHA}" \
    -t "${IMAGE}:latest" \
    -t "${IMAGE}:main" \
    -t "${IMAGE}:${SHA}" \
    --push \
    .

echo "[publish] pushed. digest:"
docker buildx imagetools inspect "${IMAGE}:latest" --format '{{.Manifest.Digest}}'

echo "[publish] watchtower polls every 60s. Confirm the box actually moved:"
echo "  ssh -i ~/.ssh/id_hetzner root@178.105.157.209 \\"
echo "    'docker inspect beam-campus-site --format \"{{.Image}}\"'"
