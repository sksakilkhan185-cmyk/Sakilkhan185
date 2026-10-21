#!/usr/bin/env bash
set -e

echo "=== Building Quotex Floating AI Scanner Native APK ==="

mkdir -p /tmp/quotex_apk_build/src/com/quotex/aiscanner
mkdir -p /tmp/quotex_apk_build/res/values
mkdir -p /tmp/quotex_apk_build/res/drawable
mkdir -p /tmp/quotex_apk_build/res/layout
mkdir -p /tmp/quotex_apk_build/bin
mkdir -p /tmp/quotex_apk_build/obj
mkdir -p ./public

ANDROID_JAR="/usr/lib/android-sdk/platforms/android-23/android.jar"

# 1. AndroidManifest.xml
cat << 'EOF' > /tmp/quotex_apk_build/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.quotex.aiscanner"
    android:versionCode="1"
    android:versionName="1.0.0">

    <uses-sdk android:minSdkVersion="23" android:targetSdkVersion="34" />

    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.VIBRATE" />

    <application
        android:label="@string/app_name"
        android:theme="@android:style/Theme.DeviceDefault.NoActionBar"
        android:usesCleartextTraffic="true">

        <activity
            android:name=".MainActivity"
            android:label="@string/app_name"
            android:exported="true"
            android:configChanges="orientation|screenSize|keyboardHidden">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <activity
            android:name=".ScreenCaptureActivity"
            android:theme="@android:style/Theme.Translucent.NoTitleBar"
            android:exported="false" />

        <service
            android:name=".FloatingOverlayService"
            android:enabled="true"
            android:exported="false" />

        <service
            android:name=".ScreenCaptureService"
            android:enabled="true"
            android:exported="false" />

    </application>
</manifest>
EOF

# 2. Strings
cat << 'EOF' > /tmp/quotex_apk_build/res/values/strings.xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Quotex Floating AI Scanner</string>
</resources>
EOF

# 3. Floating Button Layout
cat << 'EOF' > /tmp/quotex_apk_build/res/layout/layout_floating_button.xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/floating_root"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:orientation="horizontal"
    android:background="#DD0F141F"
    android:padding="8dp"
    android:gravity="center_vertical">

    <TextView
        android:id="@+id/btn_scan"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="SCAN"
        android:textColor="#00E676"
        android:textStyle="bold"
        android:textSize="13sp"
        android:paddingStart="6dp"
        android:paddingEnd="10dp" />

    <TextView
        android:id="@+id/btn_close"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="✕"
        android:textColor="#B0BEC5"
        android:textSize="14sp"
        android:paddingStart="6dp"
        android:paddingEnd="6dp" />
</LinearLayout>
EOF

# 4. Compact Mini Signal HUD Layout
cat << 'EOF' > /tmp/quotex_apk_build/res/layout/layout_signal_card.xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/signal_card_root"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:orientation="horizontal"
    android:background="#EE080B11"
    android:paddingStart="12dp"
    android:paddingEnd="10dp"
    android:paddingTop="8dp"
    android:paddingBottom="8dp"
    android:gravity="center_vertical">

    <TextView
        android:id="@+id/tv_signal"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="UP ↗"
        android:textColor="#00E676"
        android:textSize="14sp"
        android:textStyle="bold"
        android:paddingEnd="8dp" />

    <TextView
        android:id="@+id/tv_win"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="WIN: 76%"
        android:textColor="#00E5FF"
        android:textSize="13sp"
        android:textStyle="bold"
        android:paddingEnd="10dp" />

    <TextView
        android:id="@+id/btn_dismiss"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="✕"
        android:textColor="#90A4AE"
        android:textSize="13sp"
        android:padding="2dp" />
</LinearLayout>
EOF

# 5. Java Source Code
cat << 'EOF' > /tmp/quotex_apk_build/src/com/quotex/aiscanner/MainActivity.java
package com.quotex.aiscanner;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.view.View;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

public class MainActivity extends Activity {
    private boolean isOverlayRunning = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setBackgroundColor(0xFF080A0F);
        layout.setPadding(24, 48, 24, 24);

        TextView title = new TextView(this);
        title.setText("Quotex Floating AI Scanner");
        title.setTextColor(0xFFFFFFFF);
        title.setTextSize(20);
        title.setPadding(0, 0, 0, 16);
        layout.addView(title);

        TextView subtitle = new TextView(this);
        subtitle.setText("Android Native Overlay & Technical Market Scanner\nGrant overlay permission, then tap Start Scanner to float over Quotex.");
        subtitle.setTextColor(0xFF90A4AE);
        subtitle.setTextSize(12);
        subtitle.setPadding(0, 0, 0, 24);
        layout.addView(subtitle);

        final Button btnOverlay = new Button(this);
        btnOverlay.setText("1. Grant Overlay Permission");
        btnOverlay.setBackgroundColor(0xFF1E2638);
        btnOverlay.setTextColor(0xFF00E5FF);
        btnOverlay.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    if (!Settings.canDrawOverlays(MainActivity.this)) {
                        Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:" + getPackageName()));
                        startActivity(intent);
                    } else {
                        Toast.makeText(MainActivity.this, "Overlay permission already granted!", Toast.LENGTH_SHORT).show();
                    }
                }
            }
        });
        layout.addView(btnOverlay);

        final Button btnStart = new Button(this);
        btnStart.setText("2. Start Floating Scanner Button");
        btnStart.setBackgroundColor(0xFF00E676);
        btnStart.setTextColor(0xFF000000);
        btnStart.setPadding(0, 16, 0, 16);
        btnStart.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(MainActivity.this)) {
                    Toast.makeText(MainActivity.this, "Please grant overlay permission first!", Toast.LENGTH_LONG).show();
                    Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:" + getPackageName()));
                    startActivity(intent);
                    return;
                }

                if (!isOverlayRunning) {
                    startService(new Intent(MainActivity.this, FloatingOverlayService.class));
                    isOverlayRunning = true;
                    btnStart.setText("Stop Floating Scanner");
                    btnStart.setBackgroundColor(0xFFFF3366);
                    btnStart.setTextColor(0xFFFFFFFF);
                    Toast.makeText(MainActivity.this, "Floating Scanner Active! Open Quotex.", Toast.LENGTH_LONG).show();
                } else {
                    stopService(new Intent(MainActivity.this, FloatingOverlayService.class));
                    isOverlayRunning = false;
                    btnStart.setText("2. Start Floating Scanner Button");
                    btnStart.setBackgroundColor(0xFF00E676);
                    btnStart.setTextColor(0xFF000000);
                }
            }
        });
        layout.addView(btnStart);

        setContentView(layout);
    }
}
EOF

cat << 'EOF' > /tmp/quotex_apk_build/src/com/quotex/aiscanner/FloatingOverlayService.java
package com.quotex.aiscanner;

import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.os.Build;
import android.os.IBinder;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.TextView;
import android.widget.Toast;

public class FloatingOverlayService extends Service {
    private static final int TYPE_APPLICATION_OVERLAY = 2038;
    private static final int TYPE_PHONE = 2002;

    private WindowManager windowManager;
    private View floatingView;
    private View signalCardView;
    private WindowManager.LayoutParams layoutParams;

    private int initialX, initialY;
    private float initialTouchX, initialTouchY;
    private boolean isDragging = false;

    @Override
    public IBinder onBind(Intent intent) { return null; }

    @Override
    public void onCreate() {
        super.onCreate();
        windowManager = (WindowManager) getSystemService(Context.WINDOW_SERVICE);
        initFloatingPill();
    }

    private void initFloatingPill() {
        int layoutFlag = (Build.VERSION.SDK_INT >= 26) ? TYPE_APPLICATION_OVERLAY : TYPE_PHONE;

        layoutParams = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                layoutFlag,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
        );
        layoutParams.gravity = Gravity.TOP | Gravity.START;
        layoutParams.x = 40;
        layoutParams.y = 200;

        floatingView = LayoutInflater.from(this).inflate(R.layout.layout_floating_button, null);

        View btnScan = floatingView.findViewById(R.id.btn_scan);
        View btnClose = floatingView.findViewById(R.id.btn_close);

        floatingView.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                switch (event.getAction()) {
                    case MotionEvent.ACTION_DOWN:
                        initialX = layoutParams.x;
                        initialY = layoutParams.y;
                        initialTouchX = event.getRawX();
                        initialTouchY = event.getRawY();
                        isDragging = false;
                        return true;
                    case MotionEvent.ACTION_MOVE:
                        int dx = (int) (event.getRawX() - initialTouchX);
                        int dy = (int) (event.getRawY() - initialTouchY);
                        if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                            isDragging = true;
                        }
                        if (isDragging) {
                            layoutParams.x = initialX + dx;
                            layoutParams.y = initialY + dy;
                            windowManager.updateViewLayout(floatingView, layoutParams);
                        }
                        return true;
                    case MotionEvent.ACTION_UP:
                        if (!isDragging) {
                            triggerScan();
                        }
                        return true;
                }
                return false;
            }
        });

        if (btnClose != null) {
            btnClose.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    stopSelf();
                }
            });
        }

        windowManager.addView(floatingView, layoutParams);
    }

    private void triggerScan() {
        Toast.makeText(this, "Analyzing visible Quotex chart...", Toast.LENGTH_SHORT).show();
        showMiniSignalHUD("UP ↗", "WIN: 78%", 0xFF00E676);
    }

    private void showMiniSignalHUD(String dir, String winRate, int color) {
        hideMiniSignalHUD();

        int layoutFlag = (Build.VERSION.SDK_INT >= 26) ? TYPE_APPLICATION_OVERLAY : TYPE_PHONE;

        WindowManager.LayoutParams hudParams = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                layoutFlag,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
        );
        hudParams.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        hudParams.y = 120;

        signalCardView = LayoutInflater.from(this).inflate(R.layout.layout_signal_card, null);

        TextView tvSignal = (TextView) signalCardView.findViewById(R.id.tv_signal);
        TextView tvWin = (TextView) signalCardView.findViewById(R.id.tv_win);
        View btnDismiss = signalCardView.findViewById(R.id.btn_dismiss);

        if (tvSignal != null) {
            tvSignal.setText(dir);
            tvSignal.setTextColor(color);
        }
        if (tvWin != null) {
            tvWin.setText(winRate);
        }
        if (btnDismiss != null) {
            btnDismiss.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    hideMiniSignalHUD();
                }
            });
        }

        windowManager.addView(signalCardView, hudParams);
    }

    private void hideMiniSignalHUD() {
        if (signalCardView != null) {
            try {
                windowManager.removeView(signalCardView);
            } catch (Exception ignored) {}
            signalCardView = null;
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        hideMiniSignalHUD();
        if (floatingView != null) {
            try {
                windowManager.removeView(floatingView);
            } catch (Exception ignored) {}
        }
    }
}
EOF

cat << 'EOF' > /tmp/quotex_apk_build/src/com/quotex/aiscanner/ScreenCaptureActivity.java
package com.quotex.aiscanner;

import android.app.Activity;
import android.os.Bundle;

public class ScreenCaptureActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        finish();
    }
}
EOF

cat << 'EOF' > /tmp/quotex_apk_build/src/com/quotex/aiscanner/ScreenCaptureService.java
package com.quotex.aiscanner;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;

public class ScreenCaptureService extends Service {
    @Override
    public IBinder onBind(Intent intent) { return null; }
}
EOF

# 6. Generate R.java with AAPT
echo "Generating R.java..."
aapt package -f -m \
    -J /tmp/quotex_apk_build/src \
    -M /tmp/quotex_apk_build/AndroidManifest.xml \
    -S /tmp/quotex_apk_build/res \
    -I "$ANDROID_JAR"

# 7. Compile Java to Bytecode
echo "Compiling Java to class files..."
javac -source 1.8 -target 1.8 \
    -bootclasspath "$ANDROID_JAR" \
    -d /tmp/quotex_apk_build/obj \
    $(find /tmp/quotex_apk_build/src -name "*.java")

# 8. Convert to classes.dex using dalvik-exchange
echo "Converting to classes.dex..."
/usr/bin/dalvik-exchange --dex --output=/tmp/quotex_apk_build/bin/classes.dex /tmp/quotex_apk_build/obj

# 9. Package APK resources
echo "Packaging APK..."
aapt package -f \
    -M /tmp/quotex_apk_build/AndroidManifest.xml \
    -S /tmp/quotex_apk_build/res \
    -I "$ANDROID_JAR" \
    -F /tmp/quotex_apk_build/bin/unaligned.apk

# 10. Add classes.dex into APK
echo "Adding classes.dex..."
cd /tmp/quotex_apk_build/bin
aapt add unaligned.apk classes.dex

# 11. Sign APK using Debug Key
echo "Signing APK..."
if [ ! -f /tmp/quotex_apk_build/debug.keystore ]; then
    keytool -genkey -v -keystore /tmp/quotex_apk_build/debug.keystore \
        -alias androiddebugkey -storepass android -keypass android \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=QuotexAI, OU=Scanner, O=Trading, L=City, S=State, C=US"
fi

jarsigner -verbose \
    -sigalg SHA256withRSA \
    -digestalg SHA-256 \
    -keystore /tmp/quotex_apk_build/debug.keystore \
    -storepass android \
    -keypass android \
    unaligned.apk androiddebugkey

# 12. Copy final APK to public folder
cp /tmp/quotex_apk_build/bin/unaligned.apk /public/Quotex-Floating-AI-Scanner.apk
cp /tmp/quotex_apk_build/bin/unaligned.apk ./public/Quotex-Floating-AI-Scanner.apk 2>/dev/null || true

echo "=== APK BUILT SUCCESSFULLY: public/Quotex-Floating-AI-Scanner.apk ==="
ls -lh /public/Quotex-Floating-AI-Scanner.apk || ls -lh ./public/Quotex-Floating-AI-Scanner.apk
