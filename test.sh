#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tests -p 'test_release.py' -v
mkdir -p build
staging="$(mktemp -d "$PWD/build/.peons-tests.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$staging/module-cache" Sources/Characters.swift Sources/PetModel.swift Tests/ModelTests.swift -o "$staging/model-tests"
"$staging/model-tests"
xcrun swiftc -swift-version 5 -module-cache-path "$staging/module-cache" Sources/Characters.swift Sources/PetModel.swift Tests/RoamingTests.swift -o "$staging/roaming-tests"
"$staging/roaming-tests"
xcrun swiftc -swift-version 5 -module-cache-path "$staging/module-cache" Sources/Characters.swift Sources/PetModel.swift Sources/CharacterArtwork.swift Sources/SpriteRenderer.swift Tests/ArtworkTests.swift -o "$staging/artwork-tests" -framework AppKit
"$staging/artwork-tests"
xcrun swiftc -swift-version 5 -module-cache-path "$staging/module-cache" Sources/Characters.swift Sources/PetModel.swift Sources/CharacterArtwork.swift Sources/SpriteRenderer.swift Tests/SpriteHitTests.swift -o "$staging/sprite-hit-tests" -framework AppKit
"$staging/sprite-hit-tests"
xcrun swiftc -swift-version 5 -module-cache-path "$staging/module-cache" Sources/Characters.swift Sources/PetModel.swift Sources/CharacterArtwork.swift Sources/SpriteRenderer.swift Tests/SpeechTests.swift -o "$staging/speech-tests" -framework AppKit
"$staging/speech-tests"
xcrun swiftc -swift-version 5 -module-cache-path "$staging/module-cache" Sources/CanvasSlice.swift Tests/CanvasTests.swift -o "$staging/canvas-tests"
"$staging/canvas-tests"
xcrun swiftc -swift-version 5 -D APP_TESTS -module-cache-path "$staging/module-cache" Sources/*.swift Tests/AppConfigurationTests.swift -o "$staging/app-configuration-tests" -framework AppKit -framework SwiftUI -framework AVFAudio
"$staging/app-configuration-tests"
xcrun swiftc -swift-version 5 -module-cache-path "$staging/module-cache" Sources/Characters.swift Sources/Dialogue.swift Sources/VoicePlayer.swift Tests/DialogueTests.swift -o "$staging/dialogue-tests" -framework AVFAudio
"$staging/dialogue-tests"
