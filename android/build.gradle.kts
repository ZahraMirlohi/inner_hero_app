// android/build.gradle.kts

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ اضافه کردن buildscript با نسخه‌های جدید
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.9.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20")
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