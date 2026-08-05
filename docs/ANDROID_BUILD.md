# بناء Android

## الإعداد المستخدم

- Godot: 4.7.1 stable، GL Compatibility.
- Java: Eclipse Temurin JDK 17.
- Android SDK: `%LOCALAPPDATA%\Android\Sdk`.
- ABI: `arm64-v8a`.
- الحد الأدنى: Android API 24 (Android 7.0).
- الحزمة: `com.savanna.lionbattle3d`.
- الإصدار: `1.1.0`، رقم البناء 2.

## الأوامر

1. أنشئ مفتاح التوقيع المحلي مرة واحدة: `powershell -ExecutionPolicy Bypass -File scripts\create_release_key.ps1`.
2. صدّر ووقّع وانسخ APK: `scripts\prepare_release.bat`.
3. صِل هاتفًا مصرحًا عبر USB ثم نفّذ: `scripts\install_usb.bat`.
4. للتحقق المستقل: `scripts\verify_apk.bat`.

مفتاح التوقيع وكلمة مروره داخل `.secrets/`، وهذا المسار مستبعد في `.gitignore`. لا تنقل المفتاح إلى مستودع عام، واحتفظ بنسخة احتياطية آمنة منه لتوقيع التحديثات المستقبلية.

