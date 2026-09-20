#!/bin/bash
set -e

# --- 1) بناء هيكل المشروع ---
mkdir -p .github/workflows
mkdir -p app/src/main/java/com/eegnosis/atlas
mkdir -p app/src/main/res/values
mkdir -p app/src/main/assets/figures

# --- 2) build.yml ---
cat > .github/workflows/build.yml << 'YAML'
name: Build APK
on:
  push:
    branches: [ main ]
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      - uses: gradle/gradle-build-action@v2
        with:
          gradle-version: 8.2
      - run: gradle assembleDebug --stacktrace
      - uses: actions/upload-artifact@v4
        with:
          name: eegnosis-apk
          path: app/build/outputs/apk/debug/app-debug.apk
YAML

# --- 3) settings.gradle ---
cat > settings.gradle << 'EOF'
rootProject.name = "EEGnosis"
include ':app'
EOF

# --- 4) build.gradle ---
cat > build.gradle << 'EOF'
buildscript {
    repositories { google(); mavenCentral() }
    dependencies { classpath 'com.android.tools.build:gradle:8.1.4' }
}
allprojects {
    repositories { google(); mavenCentral() }
}
task clean(type: Delete) { delete rootProject.buildDir }
EOF

# --- 5) gradle.properties ---
cat > gradle.properties << 'EOF'
org.gradle.jvmargs=-Xmx2048m
android.useAndroidX=true
android.enableJetifier=true
EOF

# --- 6) app/build.gradle ---
cat > app/build.gradle << 'EOF'
plugins { id 'com.android.application' }
android {
    namespace 'com.eegnosis.atlas'
    compileSdk 34
    defaultConfig {
        applicationId "com.eegnosis.atlas"
        minSdk 21
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
    }
    buildTypes { release { minifyEnabled false } }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}
dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.webkit:webkit:1.9.0'
}
EOF

# --- 7) AndroidManifest.xml ---
cat > app/src/main/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:allowBackup="true"
        android:label="EEGnosis Atlas"
        android:theme="@style/AppTheme"
        android:hardwareAccelerated="true"
        android:usesCleartextTraffic="true">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize|keyboardHidden"
            android:screenOrientation="unspecified">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# --- 8) MainActivity.java ---
cat > app/src/main/java/com/eegnosis/atlas/MainActivity.java << 'EOF'
package com.eegnosis.atlas;
import android.os.Bundle;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebChromeClient;
import androidx.appcompat.app.AppCompatActivity;
public class MainActivity extends AppCompatActivity {
    private WebView webView;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        webView = new WebView(this);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowFileAccessFromFileURLs(true);
        settings.setAllowUniversalAccessFromFileURLs(true);
        webView.setWebViewClient(new WebViewClient());
        webView.setWebChromeClient(new WebChromeClient());
        webView.loadUrl("file:///android_asset/index.html");
        setContentView(webView);
    }
    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }
}
EOF

# --- 9) styles.xml ---
cat > app/src/main/res/values/styles.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="Theme.AppCompat.NoActionBar">
        <item name="android:windowBackground">@android:color/black</item>
        <item name="android:statusBarColor">#090d16</item>
        <item name="android:navigationBarColor">#090d16</item>
    </style>
</resources>
EOF

# --- 10) index.html (مختصر) ---
cat > app/src/main/assets/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>EEGnosis Atlas</title>
<style>
*{box-sizing:border-box;font-family:-apple-system,'Segoe UI',Roboto,sans-serif;margin:0;padding:0;-webkit-tap-highlight-color:transparent}
html,body{height:100vh;width:100vw;overflow:hidden;background:#090d16;display:flex;flex-direction:column}
.top-bar{display:flex;align-items:center;justify-content:space-between;padding:10px 16px;background:#111827;border-bottom:1px solid #1f293d}
.brand{color:#f3f4f6;font-size:1rem;font-weight:700}
.counter{color:#6b7280;font-size:.85rem;font-weight:600;background:#1f2937;padding:4px 10px;border-radius:20px}
.viewer{flex:1;display:flex;align-items:center;justify-content:center;padding:8px;overflow:hidden}
.img-frame{width:100%;height:100%;max-width:96%;max-height:96%;background:#000;border-radius:12px;border:1px solid #1f293d;display:flex;align-items:center;justify-content:center;padding:6px;overflow:hidden}
#figureImg{max-width:100%;max-height:100%;object-fit:contain;border-radius:8px;user-select:none}
.controls{padding:8px 12px;background:#111827;border-top:1px solid #1f293d;display:flex;flex-direction:column;gap:6px}
.row{display:flex;gap:6px}
button{flex:1;padding:10px 8px;border:none;border-radius:8px;font-weight:600;font-size:.78rem;cursor:pointer;color:white}
button:active{transform:scale(.96)}
.btn-nav{background:#1f2937;border:1px solid #374151;color:#e5e7eb}
.btn-nav:disabled{opacity:.3}
.btn-caption{background:#2563eb}
.btn-markings{background:#8b5cf6}
.btn-recognized{background:#16a34a}
.btn-again{background:#d97706}
.overlay{position:fixed;inset:0;background:rgba(0,0,0,.85);display:none;z-index:100;padding:20px;flex-direction:column}
.overlay.show{display:flex}
.overlay .inner{background:#0f172a;border:1px solid #2a7de1;border-radius:12px;padding:16px;flex:1;overflow-y:auto;color:#f1f5f9;font-size:.9rem;line-height:1.6;white-space:pre-wrap}
.overlay .close{margin-top:10px;padding:12px;background:#2563eb}
</style>
</head>
<body>
<div class="top-bar"><div class="brand">🧠 EEGnosis Atlas</div><div class="counter" id="counter">- / -</div></div>
<div class="viewer"><div class="img-frame"><img id="figureImg" src="" alt=""></div></div>
<div class="controls">
<div class="row">
<button class="btn-nav" id="prevBtn" onclick="nav(-1)">⬅ Prev</button>
<button class="btn-caption" onclick="toggleCaption()">📖 Caption</button>
<button class="btn-markings" onclick="toggleMarkings()">🖍️ Markings</button>
</div>
<div class="row">
<button class="btn-recognized" onclick="nav(1)">✅ Recognized</button>
<button class="btn-again" onclick="nav(1)">🔁 Again</button>
<button class="btn-nav" id="nextBtn" onclick="nav(1)">Next ➡</button>
</div>
</div>
<div class="overlay" id="ov"><div class="inner" id="ovText">Loading...</div><button class="close" onclick="toggleCaption()">إغلاق</button></div>
<script>
const START=3,END=768;let ALL=[],idx=0;
function pad(n){return n.toString().padStart(3,'0')}
function init(){for(let i=START;i<=END;i++)ALL.push({img:'figures/figure_'+pad(i)+'.jpg',txt:'figures/figure_'+pad(i)+'.txt',marked:'figures/figure_'+pad(i)+'_marked.jpg'});const s=localStorage.getItem('eeg_idx');idx=s?Math.min(parseInt(s),ALL.length-1):0;render();}
function render(){idx=Math.max(0,Math.min(idx,ALL.length-1));document.getElementById('figureImg').src=ALL[idx].img;document.getElementById('counter').textContent=(idx+1)+' / '+ALL.length;document.getElementById('prevBtn').disabled=idx===0;document.getElementById('nextBtn').disabled=idx===ALL.length-1;localStorage.setItem('eeg_idx',idx);}
function nav(d){const n=idx+d;if(n>=0&&n<ALL.length){idx=n;render();}}
function toggleCaption(){const o=document.getElementById('ov'),t=document.getElementById('ovText');if(o.classList.contains('show')){o.classList.remove('show');return;}t.textContent='Loading...';fetch(ALL[idx].txt).then(r=>r.ok?r.text():'No caption.').then(txt=>t.textContent=txt).catch(()=>t.textContent='No caption.');o.classList.add('show');}
function toggleMarkings(){document.getElementById('figureImg').src=ALL[idx].marked;}
let sx=0,sy=0;
document.querySelector('.viewer').addEventListener('touchstart',e=>{sx=e.changedTouches[0].screenX;sy=e.changedTouches[0].screenY;},{passive:true});
document.querySelector('.viewer').addEventListener('touchend',e=>{const dx=e.changedTouches[0].screenX-sx;const dy=e.changedTouches[0].screenY-sy;if(Math.abs(dx)>60&&Math.abs(dx)>Math.abs(dy))nav(dx<0?1:-1);},{passive:true});
init();
</script>
</body>
</html>
HTMLEOF

echo "=== Files created ==="
ls -la

echo "=== Committing Part 1 ==="
git add .github app/build.gradle app/src/main/AndroidManifest.xml app/src/main/java app/src/main/res app/src/main/assets/index.html build.gradle settings.gradle gradle.properties
git commit -m "Part 1: project structure"
git push origin main

echo ""
echo "=== ✅ Part 1 DONE ==="
echo ""

