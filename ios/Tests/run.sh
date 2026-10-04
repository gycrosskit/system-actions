#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/ios-policy-tests
swiftc -emit-module -emit-library -module-name UIKit ios/Tests/UIKit.swift \
  -emit-module-path build/ios-policy-tests/UIKit.swiftmodule -o build/ios-policy-tests/libUIKit.dylib
swiftc -emit-module -emit-library -module-name GYCWindowPolicy ios/Sources/GYCWindowPolicy/WindowPolicy.swift \
  -I build/ios-policy-tests -L build/ios-policy-tests -lUIKit \
  -emit-module-path build/ios-policy-tests/GYCWindowPolicy.swiftmodule -o build/ios-policy-tests/libGYCWindowPolicy.dylib
swiftc -parse-as-library ios/Tests/main.swift -I build/ios-policy-tests -L build/ios-policy-tests \
  -lUIKit -lGYCWindowPolicy -Xlinker -rpath -Xlinker "$PWD/build/ios-policy-tests" -o build/ios-policy-tests/checks
build/ios-policy-tests/checks
