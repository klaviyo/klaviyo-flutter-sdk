.PHONY: run-ios run-android clean-ios clean-android clean

# Run the example app on iOS
run-ios:
	cd example && flutter run

# Run the example app on Android
run-android:
	cd example && flutter run

# Full clean iOS build: wipe CocoaPods cache, re-run pod install, then run
clean-ios:
	cd example/ios && rm -rf Pods Podfile.lock
	cd example/ios && pod install --repo-update
	cd example && flutter run

# Full clean Android build: clear Gradle cache, then run
clean-android:
	cd example/android && ./gradlew clean
	cd example && flutter run

# Flutter clean (wipes build artifacts across all platforms)
clean:
	cd example && flutter clean
