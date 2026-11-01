DEST = platform=iOS Simulator,name=iPhone 17
.PHONY: test test-packages test-app build-app lint
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
test-app:
	xcodebuild build-for-testing -scheme Pulse -destination '$(DEST)' -quiet
	xcodebuild test-without-building -scheme Pulse -destination '$(DEST)' -quiet
lint:
	swiftlint lint --strict
