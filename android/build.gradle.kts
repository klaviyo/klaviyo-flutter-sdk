group = "com.klaviyo.klaviyo_flutter_sdk"
version = "1.0"

buildscript {
    val kotlinVersion = "1.9.25"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

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

extensions.configure<com.android.build.api.dsl.LibraryExtension> {
    compileSdk = flutter.compileSdkVersion
    namespace = "com.klaviyo.klaviyo_flutter_sdk"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 23
    }
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
    compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
}

val klaviyoSdkVersion = "4.6.0"

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

dependencies {
    "implementation"("com.github.klaviyo.klaviyo-android-sdk:core:$klaviyoSdkVersion")
    "api"("com.github.klaviyo.klaviyo-android-sdk:analytics:$klaviyoSdkVersion")
    "api"("com.github.klaviyo.klaviyo-android-sdk:push-fcm:$klaviyoSdkVersion")

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
}
