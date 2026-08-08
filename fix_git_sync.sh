#!/usr/bin/env bash
set -e

echo "== Installing missing dependencies =="
sudo apt-get update -y && sudo apt-get install -y xdg-utils w3m

cd "$HOME/pixel-terminal-master"
echo "== Configuring Remote and Tracking =="
git remote set-url origin https://github.com/bilbywilby/pixel-terminal-master.git
git fetch origin

echo "== Reconciling local and remote histories =="
git branch --set-upstream-to=origin/main main
git config pull.rebase false
git pull origin main --allow-unrelated-histories --no-edit

echo "== Pushing local work to GitHub =="
git push -u origin main

echo "== Repository successfully synchronized! =="
