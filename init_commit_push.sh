#!/bin/bash

set -e

# === User Config ===
branch="main"
remote_url="https://github.com/Jasxh-Dumps/realme-GT7_Dump.git"
description="realme GT7 initial dump"

# === Initialize Git ===
if [ ! -d ".git" ]; then
    echo "[+] Initializing Git repository..."
    git init
    git remote add origin "$remote_url"
    git checkout -b "$branch"
else
    echo "[+] Git repo already initialized."
fi

# === Git LFS and Commit Function ===
commit_and_push() {
    local DIRS=(
        "system_ext"
        "product"
        "system_dlkm"
        "odm"
        "odm_dlkm"
        "vendor_dlkm"
        "vendor"
        "system"
    )

    echo "[+] Setting up Git LFS..."
    git lfs install

    # Track files >100MB
    if [ ! -e ".gitattributes" ]; then
        echo "[+] Tracking files >100MB with Git LFS..."
        find . -type f -not -path ".git/*" -size +100M -exec git lfs track {} \;
    fi

    if [ -e ".gitattributes" ]; then
        git add ".gitattributes"
        git commit -sm "Setup Git LFS"
        git push -u origin "${branch}"
    fi

    # Add APKs
    echo "[+] Adding APKs..."
    find . -type f -name '*.apk' -exec git add {} +
    git commit -sm "Add apps for ${description}" || echo "[!] No APKs to commit"
    git push -u origin "${branch}"

    # Add key partitions
    for i in "${DIRS[@]}"; do
        [ -d "${i}" ] && git add "${i}"
        [ -d "system/${i}" ] && git add "system/${i}"
        [ -d "system/system/${i}" ] && git add "system/system/${i}"
        [ -d "vendor/${i}" ] && git add "vendor/${i}"

        git commit -sm "Add ${i} for ${description}" || echo "[!] Nothing new in ${i}"
        git push -u origin "${branch}"
    done

    # Add remaining extras
    git add .
    git commit -sm "Add extras for ${description}" || echo "[!] No extras to commit"
    git push -u origin "${branch}"
}

# === Run the function ===
commit_and_push
