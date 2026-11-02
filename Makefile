DEST = platform=iOS Simulator,name=iPhone 17
.PHONY: test test-packages test-app build-app check-versions build-release lint
test: lint test-packages test-app
test-packages:
	swift test --package-path Packages/PulseDomain
	swift test --package-path Packages/PulseRecoveryEngine
	swift test --package-path Packages/PulseContent
	swift test --package-path Packages/PulsePersistence
	swift test --package-path Packages/PulseDesignSystem
	swift test --package-path Packages/PulseFeatures
build-app:
	xcodebuild build-for-testing -scheme Pulse -destination 'generic/platform=iOS Simulator' -quiet
check-versions:
	@for key in CFBundleShortVersionString CFBundleVersion; do \
		app=$$(/usr/libexec/PlistBuddy -c "Print :$$key" Pulse/Info.plist) || exit 1; \
		widgets=$$(/usr/libexec/PlistBuddy -c "Print :$$key" PulseWidgets/Info.plist) || exit 1; \
		if [ "$$app" != "$$widgets" ]; then \
			echo "error: $$key differs: Pulse/Info.plist=$$app, PulseWidgets/Info.plist=$$widgets" >&2; \
			exit 1; \
		fi; \
	done
build-release: check-versions
	swift build -c release --package-path Packages/PulseDesignSystem
	swift build -c release --package-path Packages/PulseFeatures
	xcodebuild build -scheme Pulse -configuration Release -destination 'generic/platform=iOS Simulator' -quiet
test-app:
	xcodebuild build-for-testing -scheme Pulse -destination '$(DEST)' -quiet
	xcodebuild test-without-building -scheme Pulse -destination '$(DEST)' -quiet
lint:
	swiftlint lint --strict
