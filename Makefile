DEST = platform=iOS Simulator,name=iPhone 17
.PHONY: test test-packages test-app build-app build-release lint
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
build-release:
	swift build -c release --package-path Packages/PulseDesignSystem
	swift build -c release --package-path Packages/PulseFeatures
	xcodebuild build -scheme Pulse -configuration Release -destination 'generic/platform=iOS Simulator' -quiet
test-app:
	xcodebuild build-for-testing -scheme Pulse -destination '$(DEST)' -quiet
	xcodebuild test-without-building -scheme Pulse -destination '$(DEST)' -quiet
lint:
	swiftlint lint --strict
