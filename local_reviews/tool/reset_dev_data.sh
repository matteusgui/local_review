#!/usr/bin/env bash
#
# Wipes this app's local dev data (Linux desktop only) so the next
# `flutter run` behaves like a fresh install: no recovery seed in the
# keyring, no encrypted database, no saved posters.
#
# The app checks for a saved seed before it checks for a database file,
# so clearing only the database is NOT enough to see onboarding again —
# the keyring entry has to go too, or the app just silently recreates an
# empty database under the same identity.
#
# Usage:
#   tool/reset_dev_data.sh          # asks for confirmation first
#   tool/reset_dev_data.sh -y       # skips the confirmation prompt

set -euo pipefail

# Matches APPLICATION_ID in linux/CMakeLists.txt. Update both together if
# that ever changes.
readonly APPLICATION_ID="com.example.local_reviews"
readonly DB_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/$APPLICATION_ID/local_reviews.sqlite"

if command -v xdg-user-dir >/dev/null 2>&1; then
  DOCUMENTS_DIR="$(xdg-user-dir DOCUMENTS)"
else
  DOCUMENTS_DIR="$HOME/Documents"
fi
readonly DOCUMENTS_DIR
readonly POSTERS_DIR="$DOCUMENTS_DIR/posters"

echo "This will delete:"
echo "  - Keyring entry: account=$APPLICATION_ID.secureStorage"
echo "  - Database:      $DB_PATH"
echo "  - Posters dir:   $POSTERS_DIR"
echo

if [[ "${1:-}" != "-y" ]]; then
  read -r -p "Continue? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

if command -v secret-tool >/dev/null 2>&1; then
  if secret-tool clear account "$APPLICATION_ID.secureStorage"; then
    echo "Keyring entry cleared."
  else
    echo "No matching keyring entry found (already clear, or never set)."
  fi
else
  echo
  echo "WARNING: secret-tool not found (package: libsecret-tools)."
  echo "The recovery seed is still in your keyring — the app will NOT show"
  echo "onboarding until it's cleared. Either:"
  echo "  sudo apt-get install libsecret-tools"
  echo "  tool/reset_dev_data.sh -y"
  echo "or open 'Passwords and Keys' (Seahorse), find the entry labeled"
  echo "'$APPLICATION_ID/FlutterSecureStorage', and delete it manually."
fi

rm -f "$DB_PATH"
rm -rf "$POSTERS_DIR"

echo "Done. Database and posters removed."
