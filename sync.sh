#!/bin/bash

if [ -n "$(git status --porcelain)" ]; then 
  git add -A
  COMMIT_MESSAGE=$(git status --porcelain | ruby -ne 'puts $_.gsub(/^M /, "Changed").gsub(/^A /, "Added")')
  git commit -m "$COMMIT_MESSAGE"
fi

git pull
git push
