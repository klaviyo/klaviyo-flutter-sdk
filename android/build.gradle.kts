rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}

apply(plugin = "com.android.library")

// AGP 9+ compiles Kotlin itself unless the host sets android.builtInKotlin=false.
val agpMajorVersion =
    com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION
        .substringBefore('.')
        .toInt()
val builtInKotlin =
    agpMajorVersion >= 9 &&
        providers.gradleProperty("android.builtInKotlin").orNull?.toBoolean() != false
if (!builtInKotlin) {
    apply(plugin = "kotlin-android")
}

// Reads the `flutter` extension reflectively: its type is not on this script's classpath in add-to-app hosts.
// Older Flutter declares compileSdkVersion as a public field; newer versions expose a getter.
val flutterCompileSdk: Int =
    extensions.findByName("flutter")?.let { flutter ->
        runCatching { flutter.javaClass.getMethod("getCompileSdkVersion").invoke(flutter) as? Int }.getOrNull()
            ?: runCatching { flutter.javaClass.getField("compileSdkVersion").get(flutter) as? Int }.getOrNull()
    } ?: 36

extensions.configure<com.android.build.api.dsl.LibraryExtension> {
    compileSdk = flutterCompileSdk
    namespace = "com.klaviyo.klaviyo_flutter_sdk"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 23
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
        unitTests.all {
            it.testLogging {
                events("passed", "skipped", "failed")
                exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
            }
        }
    }
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
    compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
}

val klaviyoSdkVersion = "rel~4.7.0-SNAPSHOT"

// Matches Groovy's String.toBoolean(): "true", "y" or "1", trimmed and case-insensitive.
fun booleanProperty(
    name: String,
    default: Boolean,
): Boolean =
    rootProject
        .findProperty(name)
        ?.toString()
        ?.trim()
        ?.lowercase()
        ?.let { it == "true" || it == "y" || it == "1" }
        ?: default

// Whether to include the full forms module (in-app forms rendering).
// Set klaviyoIncludeForms=false in your host app's gradle.properties to exclude forms.
val includeForms = booleanProperty("klaviyoIncludeForms", true)

// Whether to include the Mobile Inbox module. The native inbox module is not
// published yet, so this defaults to FALSE (opt-in): the default build compiles
// the `inboxDisabled` stub and needs no inbox artifact on its classpath. Set
// klaviyoIncludeInbox=true in your host app's gradle.properties to compile the
// real bridge in `src/inboxEnabled`.
val includeInbox = booleanProperty("klaviyoIncludeInbox", false)

extensions.configure<com.android.build.api.dsl.LibraryExtension> {
    sourceSets {
        // Exactly one of these is on the compile classpath: both declare the
        // same `internal object InboxBridge`, so plugin code is identical.
        getByName("main") {
            java.srcDir(if (includeInbox) "src/inboxEnabled/kotlin" else "src/inboxDisabled/kotlin")
        }
        // Each bridge's own tests, compiled only alongside that bridge: the
        // disabled tests assert INBOX_UNAVAILABLE and the enabled ones assert
        // the native observer contract, so neither applies to the other build.
        getByName("test") {
            java.srcDir(
                if (includeInbox) {
                    "src/inboxEnabled/test/kotlin"
                } else {
                    "src/inboxDisabled/test/kotlin"
                },
            )
        }
    }
}

dependencies {
    "implementation"("com.github.klaviyo.klaviyo-android-sdk:core:$klaviyoSdkVersion")
    "api"("com.github.klaviyo.klaviyo-android-sdk:analytics:$klaviyoSdkVersion")
    "api"("com.github.klaviyo.klaviyo-android-sdk:push-fcm:$klaviyoSdkVersion")

    // Mobile Inbox: opt-in while the native module is unreleased.
    //
    // The inbox artifacts are not in any published release yet, so they only
    // resolve against a JitPack branch build such as
    // `feat~mobile-inbox-SNAPSHOT`. Point the whole SDK at one branch with
    // `scripts/configure-sdk.sh --android-branch <branch>`, which rewrites
    // klaviyoSdkVersion; a host can also set klaviyoInboxVersion to build the
    // inbox module from a different ref than the rest of the SDK.
    if (includeInbox) {
        val inboxVersion = providers.gradleProperty("klaviyoInboxVersion").orNull ?: klaviyoSdkVersion
        "api"("com.github.klaviyo.klaviyo-android-sdk:inbox:$inboxVersion")
    }

    // Location: full module (includes -core transitively), or just -core for lightweight
    val includeLocation = booleanProperty("klaviyoIncludeLocation", false)

    if (includeLocation) {
        "api"("com.github.klaviyo.klaviyo-android-sdk:location:$klaviyoSdkVersion")
    } else {
        "implementation"("com.github.klaviyo.klaviyo-android-sdk:location-core:$klaviyoSdkVersion")
    }

    // Forms: full module (includes -core transitively), or just -core for lightweight
    if (includeForms) {
        "api"("com.github.klaviyo.klaviyo-android-sdk:forms:$klaviyoSdkVersion")
    } else {
        "implementation"("com.github.klaviyo.klaviyo-android-sdk:forms-core:$klaviyoSdkVersion")
    }

    "implementation"("com.google.firebase:firebase-messaging:24.1.0")

    "testImplementation"("junit:junit:4.13.2")
    "testImplementation"("org.robolectric:robolectric:4.14.1")
    "testImplementation"("io.mockk:mockk:1.14.12")
}
