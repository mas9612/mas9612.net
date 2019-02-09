#!/bin/sh

cd ~/mas9612.github.io

git add .
git commit -m "deployed at `TZ=Asia/Tokyo date +%Y-%m-%dT%T+09:00` from CircleCI"

if [ $? = 0 ]; then
    git push origin master
fi
