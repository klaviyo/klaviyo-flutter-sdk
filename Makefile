.PHONY: run-ios run-android clean-ios clean-android clean

# Run the example app on iOS
run-ios:
	cd example && flutter run -d ios

# Run the example app on Android
run-android:
	cd example && flutter run -d android

# Full clean iOS build: wipe CocoaPods cache, re-run pod install, then run
clean-ios:
	cd example/ios && rm -rf Pods Podfile.lock && pod install --repo-update
	cd example && flutter run -d ios

# Full clean Android build: clear Gradle cache, then run
clean-android:
	cd example/android && ./gradlew clean
	cd example && flutter run -d android

# Flutter clean (wipes build artifacts across all platforms)
clean:
	cd example && flutter clean
