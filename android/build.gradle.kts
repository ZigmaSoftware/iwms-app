import com.android.build.api.dsl.ApplicationExtension
import com.android.build.gradle.LibraryExtension
import org.gradle.api.JavaVersion
import org.gradle.api.Project
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

private fun LibraryExtension.enforceSdkLevels() {
    if ((compileSdk ?: 0) < 34) {
        compileSdk = 34
    }
    ndkVersion = "27.0.12077973"
    defaultConfig {
        if (targetSdk == null || targetSdk!! < 34) {
            targetSdk = 34
        }
        if ((minSdk ?: 0) < 23) {
            minSdk = 23
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

private fun ApplicationExtension.enforceSdkLevels() {
    if ((compileSdk ?: 0) < 34) {
        compileSdk = 34
    }
    ndkVersion = "27.0.12077973"
    defaultConfig {
        if (targetSdk == null || targetSdk!! < 34) {
            targetSdk = 34
        }
        if ((minSdk ?: 0) < 21) {
            minSdk = 21
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

private fun Project.runNowOrAfterEvaluate(block: Project.() -> Unit) {
    if (state.executed) {
        block()
    } else {
        afterEvaluate { block() }
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val sharedBuildDir: Directory = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.set(sharedBuildDir)

subprojects {
    layout.buildDirectory.set(sharedBuildDir.dir(project.name))
    if (path != ":app") {
        evaluationDependsOn(":app")
    }

    configurations.configureEach {
        resolutionStrategy {
            force(
                "org.jetbrains.kotlin:kotlin-stdlib:2.1.0",
                "org.jetbrains.kotlin:kotlin-stdlib-common:2.1.0",
                "org.jetbrains.kotlin:kotlin-stdlib-jdk7:2.1.0",
                "org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.1.0",
                "org.jetbrains.kotlin:kotlin-reflect:2.1.0"
            )
        }
    }

    runNowOrAfterEvaluate {
        extensions.findByType(LibraryExtension::class.java)?.enforceSdkLevels()
        extensions.findByType(ApplicationExtension::class.java)?.enforceSdkLevels()
        tasks.withType(KotlinCompile::class.java).configureEach {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }

    if (name == "flutter_bluetooth_serial") {
        runNowOrAfterEvaluate {
            extensions.findByType(LibraryExtension::class.java)?.let { androidExt ->
                if (androidExt.namespace.isNullOrBlank()) {
                    androidExt.namespace = "io.github.edufolly.flutterbluetoothserial"
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
