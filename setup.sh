#!/bin/sh

# Installs dependencies and does initial setup for building flynnlint.  These include:
# - installing homebrew
# - installing carthage


# HOMEBREW
if which brew >/dev/null; then
  echo "homebrew detected, skipping install..."
else
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

# CARTHAGE
if which carthage >/dev/null; then
  echo "carthage detected, skipping install..."
else
  brew install carthage
fi

# RUN CARTHAGE TO GET DEPENDENCIES
if [ -d "Carthage" ]; then
	echo "carthage directory found, skipping carthage update..."
else
	carthage update --use-submodules --platform macOS
fi

