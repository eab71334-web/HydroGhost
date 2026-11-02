# Hydro Ghost (Godot 4.3)

لعبة ثلاثية الأبعاد: شخصية مكعبات، زر يحوّلك إلى ماء، وتدخل جسم أي شخص وتتحكم فيه.

## التحكم
- جوال: عصا يسار للحركة، اسحب يمين لتدوير الكاميرا، أزرار JUMP / WATER / POSSESS
- كمبيوتر: WASD حركة، Space قفز، E ماء، F تلبّس

## GitHub
```
git init && git add . && git commit -m "init"
git branch -M main
git remote add origin https://github.com/USERNAME/hydro-ghost.git
git push -u origin main
```
بعد الدفع يشتغل Workflow منفصل لكل منصة (تبويب Actions):
- **Android APK** ← ملف HydroGhost-v1.0.0.apk في Artifacts (تنزله وتثبته مباشرة)
- **iOS IPA (unsigned)** ← ملف HydroGhost-v1.0.0.ipa غير موقّع (للتثبيت عبر AltStore / Sideloadly)

الإصدار: 1.0.0 (version code 1). لتغييره عدّل `version/name` و `version/code` في android.yml، و `short_version` و `version` في ios.yml، واسم الـ artifact.
