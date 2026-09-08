#!/usr/bin/env python3
"""Prepare and publish release refs without losing newer main commits."""

import argparse
from pathlib import Path
import re
import subprocess
import sys


TAG_PATTERN = re.compile(r"v(\d+\.\d+\.\d+)-(\d+)")
BOT_NAME = "github-actions[bot]"
BOT_EMAIL = "41898282+github-actions[bot]@users.noreply.github.com"


def git(*args):
    return subprocess.run(
        ["git", *args], check=True, text=True, stdout=subprocess.PIPE,
    ).stdout.strip()


def metadata(text):
    def value(key, pattern):
        matches = re.findall(rf"<key>{key}</key><string>({pattern})</string>", text)
        if len(matches) != 1:
            raise ValueError(f"Expected one valid {key} in build.sh")
        return matches[0]

    return (
        value("CFBundleShortVersionString", r"\d+\.\d+\.\d+"),
        int(value("CFBundleVersion", r"\d+")),
    )


def version_key(version, build):
    return (*map(int, version.split(".")), int(build))


def clean_checkout():
    if git("status", "--porcelain", "--untracked-files=no"):
        raise ValueError("Release preparation requires a clean tracked checkout")


def refresh_main():
    git("fetch", "--tags", "origin", "+refs/heads/main:refs/remotes/origin/main")
    return git("rev-parse", "refs/remotes/origin/main")


def release_info(state, commit):
    version, build = metadata(git("show", f"{commit}:build.sh"))
    return dict(state=state, version=version, build=build,
                tag=f"v{version}-{build}", commit=commit)


def prepare(source):
    clean_checkout()
    source = git("rev-parse", "--verify", f"{source}^{{commit}}")
    if git("rev-parse", "HEAD") != source:
        raise ValueError("Checkout must match the commit that passed CI")
    main = refresh_main()

    if main != source:
        # A rerun can finish the release commit made by this exact CI run.
        parents = git("rev-list", "--parents", "-n", "1", main).split()[1:]
        message = git("show", "-s", "--format=%B", main).splitlines()
        changed = git("diff", "--name-only", source, main).splitlines()
        if (parents != [source] or f"Peons-Release-Source: {source}" not in message
                or sorted(changed) != ["CHANGELOG.md", "build.sh"]):
            print("Skipping superseded CI commit; main has newer changes.", file=sys.stderr)
            return dict(state="skip")
        info = release_info("existing", main)
        if info["tag"] not in git("tag", "--points-at", main).splitlines():
            raise ValueError("Release commit is missing its matching tag")
        git("checkout", "--detach", main)
        return info

    info = release_info("existing", source)
    if info["tag"] in git("tag", "--points-at", source).splitlines():
        return info

    version, build = info["version"], info["build"]
    tags = [match for tag in git("tag", "--list", "v*").splitlines()
            if (match := TAG_PATTERN.fullmatch(tag))]
    if any(version_key(match[1], 0) > version_key(version, 0) for match in tags):
        raise ValueError("build.sh version is older than an existing release tag")
    # Build numbers keep increasing even when the marketing version changes.
    build = max([build, *(int(match[2]) for match in tags)]) + 1
    tag = f"v{version}-{build}"
    build_path, changelog_path = Path("build.sh"), Path("CHANGELOG.md")
    build_text = re.sub(
        r"(<key>CFBundleVersion</key><string>)\d+(</string>)",
        lambda match: f"{match[1]}{build}{match[2]}", build_path.read_text(),
    )
    changelog = changelog_path.read_text()
    if changelog.splitlines().count("## Unreleased") != 1:
        raise ValueError("CHANGELOG.md must contain exactly one Unreleased heading")
    heading = f"## {version} (build {build})"
    if heading in changelog.splitlines():
        raise ValueError(f"CHANGELOG.md already contains {heading}")
    changelog = changelog.replace("## Unreleased\n", f"## Unreleased\n\n{heading}\n", 1)
    build_path.write_text(build_text)
    changelog_path.write_text(changelog)
    git("add", "--", "build.sh", "CHANGELOG.md")
    git("-c", f"user.name={BOT_NAME}", "-c", f"user.email={BOT_EMAIL}",
        "commit", "-m", f"Release {tag}", "-m", f"Peons-Release-Source: {source}")
    git("tag", tag)
    return release_info("prepared", git("rev-parse", "HEAD"))


def push(source, tag, commit):
    """Publish both refs atomically, only after this checkout was built and tested."""
    clean_checkout()
    if not TAG_PATTERN.fullmatch(tag):
        raise ValueError("Invalid release tag")
    if git("rev-parse", "HEAD") != commit or git("rev-parse", f"{tag}^{{commit}}") != commit:
        raise ValueError("Release commit and tag must match the tested checkout")
    main = refresh_main()
    if main == commit:
        remote_tag = git("ls-remote", "origin", f"refs/tags/{tag}", f"refs/tags/{tag}^{{}}")
        if not any(line.split()[0] == commit for line in remote_tag.splitlines()):
            raise ValueError("Published release commit is missing its matching remote tag")
        return dict(ready="true")
    if main != source:
        print("Skipping release; main advanced while the package was being tested.", file=sys.stderr)
        return dict(ready="false")
    try:
        # No force push: a racing merge rejects both the main update and the tag.
        git("push", "--atomic", "origin", f"{commit}:refs/heads/main", f"refs/tags/{tag}")
    except subprocess.CalledProcessError:
        if refresh_main() not in (source, commit):
            print("Skipping release; another commit won the push race.", file=sys.stderr)
            return dict(ready="false")
        raise
    return dict(ready="true")


def check_cask(cask, version, build):
    match = re.search(r'^  version "(\d+\.\d+\.\d+),(\d+)"$', Path(cask).read_text(), re.M)
    if not match:
        raise ValueError("Cannot read the existing Homebrew cask version")
    if version_key(version, build) < version_key(match[1], match[2]):
        raise ValueError(f"Refusing to downgrade Homebrew from {match[1]},{match[2]}")
    return {}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("prepare").add_argument("source")
    publish = commands.add_parser("push")
    publish.add_argument("source")
    publish.add_argument("tag")
    publish.add_argument("commit")
    cask = commands.add_parser("check-cask")
    cask.add_argument("cask")
    cask.add_argument("version")
    cask.add_argument("build", type=int)
    args = parser.parse_args()
    try:
        if args.command == "prepare":
            result = prepare(args.source)
        elif args.command == "push":
            result = push(args.source, args.tag, args.commit)
        else:
            result = check_cask(args.cask, args.version, args.build)
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"Release failed: {error}", file=sys.stderr)
        return 1
    for key, value in result.items():
        print(f"{key}={value}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
