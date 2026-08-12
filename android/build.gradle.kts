// android/build.gradle.kts

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ اضافه کردن buildscript
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.7.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.0.21")
    }
}

val newBuildDir: java.io.File = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
    .asFile

rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: java.io.File = newBuildDir.resolve(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}