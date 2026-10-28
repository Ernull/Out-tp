name: Build TapsiMarket Cloner APK

on:
  push:
    branches: [ "*" ]
  pull_request:
    branches: [ "*" ]
  workflow_dispatch:

permissions:
  contents: write

jobs:
  build-android-apk:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Configure Android SDK Licenses
        shell: bash
        run: |
          mkdir -p "$ANDROID_HOME/licenses"
          printf "\n24333f8a63b6825ea9c5514f83c2829b004d1fee\nd56f5187479451eabf01fb78af6dfcb131a6481e\n8933bad161af4178b1185d1a37fbf41ea5269c55" > "$ANDROID_HOME/licenses/android-sdk-license"
          printf "\n84831b9409646a918e30573bab4c9c91346d8abd\n504667f4c0de7af1a06de9f4b1727b84351f2910" > "$ANDROID_HOME/licenses/android-sdk-preview-license"

      - name: Set up Gradle
        uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: '8.7'

      - name: Generate Android Studio Project Files
        shell: bash
        run: |
          mkdir -p app/src/main/java/ir/hyperlink/cloner
          mkdir -p app/src/main/res/drawable
          mkdir -p app/src/main/res/values

          cat << 'EOF' > settings.gradle
          pluginManagement {
              repositories {
                  google()
                  mavenCentral()
                  gradlePluginPortal()
              }
          }
          dependencyResolutionManagement {
              repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
              repositories {
                  google()
                  mavenCentral()
              }
          }
          rootProject.name = "TapsiMarketCloner"
          include ':app'
          EOF

          cat << 'EOF' > build.gradle
          plugins {
              id 'com.android.application' version '8.3.2' apply false
          }
          EOF

          cat << 'EOF' > gradle.properties
          org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
          android.useAndroidX=false
          EOF

          cat << 'EOF' > app/build.gradle
          plugins {
              id 'com.android.application'
          }

          android {
              namespace 'ir.hyperlink.cloner'
              compileSdk 34

              defaultConfig {
                  applicationId "ir.hyperlink.cloner"
                  minSdk 23
                  targetSdk 34
                  versionCode 10
                  versionName "1.0"
              }

              buildTypes {
                  release {
                      minifyEnabled false
                      signingConfig signingConfigs.debug
                  }
                  debug {
                      applicationIdSuffix ""
                  }
              }

              compileOptions {
                  sourceCompatibility JavaVersion.VERSION_17
                  targetCompatibility JavaVersion.VERSION_17
              }
          }

          dependencies {
          }
          EOF

          cat << 'EOF' > app/src/main/res/drawable/ic_launcher.xml
          <vector xmlns:android="http://schemas.android.com/apk/res/android"
              android:width="108dp"
              android:height="108dp"
              android:viewportWidth="108"
              android:viewportHeight="108">
              <path
                  android:fillColor="#0B0F19"
                  android:pathData="M0,0h108v108h-108z"/>
              <path
                  android:fillColor="#10B981"
                  android:pathData="M33,30h42v12h-42zM27,48h54v30h-54z"/>
              <path
                  android:fillColor="#38BDF8"
                  android:pathData="M46,54h16v18h-16z"/>
          </vector>
          EOF

          cat << 'EOF' > app/src/main/res/values/strings.xml
          <resources>
              <string name="app_name">Tapsi Cloner</string>
          </resources>
          EOF

          cat << 'EOF' > app/src/main/AndroidManifest.xml
          <?xml version="1.0" encoding="utf-8"?>
          <manifest xmlns:android="http://schemas.android.com/apk/res/android">

              <uses-permission android:name="android.permission.INTERNET" />
              <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
              <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
              <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

              <application
                  android:allowBackup="true"
                  android:icon="@drawable/ic_launcher"
                  android:label="@string/app_name"
                  android:supportsRtl="true"
                  android:usesCleartextTraffic="true"
                  android:theme="@android:style/Theme.Material.NoActionBar">

                  <activity
                      android:name=".MainActivity"
                      android:configChanges="orientation|screenSize|keyboardHidden"
                      android:exported="true"
                      android:windowSoftInputMode="adjustResize">
                      <intent-filter>
                          <action android:name="android.intent.action.MAIN" />
                          <category android:name="android.intent.category.LAUNCHER" />
                      </intent-filter>
                  </activity>
              </application>

          </manifest>
          EOF

          cat << 'EOF' > app/src/main/java/ir/hyperlink/cloner/MainActivity.java
          package ir.hyperlink.cloner;

          import android.Manifest;
          import android.annotation.SuppressLint;
          import android.app.Activity;
          import android.content.ClipData;
          import android.content.ClipboardManager;
          import android.content.Context;
          import android.content.pm.PackageManager;
          import android.graphics.Bitmap;
          import android.graphics.Color;
          import android.graphics.Typeface;
          import android.graphics.drawable.GradientDrawable;
          import android.net.Uri;
          import android.os.Build;
          import android.os.Bundle;
          import android.os.Handler;
          import android.os.Looper;
          import android.os.Message;
          import android.text.TextUtils;
          import android.util.Base64;
          import android.util.TypedValue;
          import android.view.Gravity;
          import android.view.View;
          import android.view.ViewGroup;
          import android.view.Window;
          import android.webkit.CookieManager;
          import android.webkit.GeolocationPermissions;
          import android.webkit.JavascriptInterface;
          import android.webkit.WebChromeClient;
          import android.webkit.WebResourceRequest;
          import android.webkit.WebResourceResponse;
          import android.webkit.WebSettings;
          import android.webkit.WebStorage;
          import android.webkit.WebView;
          import android.webkit.WebViewClient;
          import android.widget.Button;
          import android.widget.CheckBox;
          import android.widget.EditText;
          import android.widget.FrameLayout;
          import android.widget.LinearLayout;
          import android.widget.ProgressBar;
          import android.widget.ScrollView;
          import android.widget.TextView;
          import android.widget.Toast;

          import org.json.JSONArray;
          import org.json.JSONObject;

          import java.io.BufferedReader;
          import java.io.InputStream;
          import java.io.InputStreamReader;
          import java.io.OutputStream;
          import java.net.HttpURLConnection;
          import java.net.URL;
          import java.net.URLEncoder;
          import java.nio.charset.StandardCharsets;
          import java.util.ArrayList;
          import java.util.Arrays;
          import java.util.HashSet;
          import java.util.LinkedHashSet;
          import java.util.List;
          import java.util.Locale;
          import java.util.Map;
          import java.util.Set;
          import java.util.UUID;
          import java.util.concurrent.CountDownLatch;
          import java.util.concurrent.TimeUnit;
          import java.util.concurrent.atomic.AtomicBoolean;

          public class MainActivity extends Activity {

              private static final String LICENSE_API_BASE = "https://testtok-production1.up.railway.app/api/tapsi/get-license/";
              private static final String TAPSI_MARKET_AUTH_URL = "https://www.tapsi.markets/tapsi-auth?source_app=WEBAPP&source_app_version=7.81.0&utm_medium=tile&utm_source=superapp";
              private static final String TAPSI_MARKET_GATEWAY = "https://apigateway.tapsi.markets";
              private static final String DEFAULT_USER_AGENT = "Mozilla/5.0 (Linux; Android 13; SM-A346E) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Mobile Safari/537.36";

              // پالت رنگی مدرن و تاریک
              private static final String COLOR_BG_MAIN = "#0B0F19";
              private static final String COLOR_BG_CARD = "#161F30";
              private static final String COLOR_BG_INPUT = "#0F172A";
              private static final String COLOR_BORDER = "#2A364F";
              private static final String COLOR_ACCENT = "#38BDF8";
              private static final String COLOR_SUCCESS = "#10B981";
              private static final String COLOR_WARNING = "#F59E0B";
              private static final String COLOR_ERROR = "#F87171";
              private static final String COLOR_PURPLE = "#A855F7";
              private static final String COLOR_TEXT_MAIN = "#F8FAFC";
              private static final String COLOR_TEXT_MUTED = "#94A3B8";

              private static final Set<String> RESERVED_COOKIE_ATTRS = new HashSet<>(Arrays.asList(
                      "path", "domain", "expires", "max-age", "secure", "httponly", "samesite"
              ));

              private static final String[] TARGET_DOMAINS = new String[]{
                      ".tapsi.cab", "app.tapsi.cab", "tapsi.cab",
                      ".tapsi.ir", "accounts.tapsi.ir", "accounts-api.tapsi.ir", "tapsi.ir",
                      ".tapsi.markets", "www.tapsi.markets", "apigateway.tapsi.markets", "tapsi.markets",
                      ".tapsi.shop", "tapsi.shop"
              };

              // ویجت‌های رابط کاربری
              private TextView statusBadge;
              private ProgressBar progressBar;
              private EditText licensesInput;
              private TextView licenseCountLabel;
              private CheckBox cloneAddressCheck;
              private CheckBox cloneCartCheck;

              private LinearLayout sourcePreviewCard;
              private TextView sourceAddressText;
              private TextView sourceCartText;
              private Button switchAddressBtn;

              private Button readSourceBtn;
              private Button startCloneBtn;
              private Button stopBtn;
              private Button toggleWebViewBtn;

              private FrameLayout webViewContainer;
              private WebView webView;
              private TextView logView;
              private ScrollView logScrollView;

              // وضعیت اجرای برنامه
              private final Handler mainHandler = new Handler(Looper.getMainLooper());
              private final AtomicBoolean isRunning = new AtomicBoolean(false);
              private final AtomicBoolean stopRequested = new AtomicBoolean(false);

              // متغیرهای همگام‌سازی احراز هویت WebView
              private volatile String activeStepId = "";
              private volatile String activeLicenseKey = "";
              private volatile String activeCookiesRaw = "";
              private volatile String activeLocalStorageRaw = "{}";
              private volatile String capturedBearerToken = null;
              private volatile String capturedSessionId = UUID.randomUUID().toString();
              private volatile CountDownLatch tokenLatch = null;

              // داده‌های استخراج‌شده از لایسنس اول (مبدأ)
              private SourceCloneData cachedSourceData = null;
              private String cachedSourceLicenseKey = null;

              // مدل‌های داده
              private static class AddressModel {
                  long id;
                  String address;
                  String cityName;
                  int cityId;
                  long customerId;
                  boolean isDefault;
                  double lat;
                  double lng;
                  String plaque;
                  String unit;
                  String title;
                  int addressTypeId;
                  String sectorIdStr;
                  String sectorPartIdStr;
                  String mobilePhone;
              }

              private static class CartItemModel {
                  long productId;
                  int quantity;
                  String productName;
                  double price;
                  double okPrice;
              }

              private static class StoreCartModel {
                  int storeId;
                  String storeName;
                  double totalOkPrice;
                  String deliveryMethod;
                  List<CartItemModel> items = new ArrayList<>();
              }

              private static class SourceCloneData {
                  String licenseKey;
                  long customerId;
                  String phone;
                  List<AddressModel> allAddresses = new ArrayList<>();
                  int selectedAddressIndex = 0;
                  List<StoreCartModel> carts = new ArrayList<>();

                  AddressModel getSelectedAddress() {
                      if (allAddresses.isEmpty()) return null;
                      if (selectedAddressIndex < 0 || selectedAddressIndex >= allAddresses.size()) {
                          selectedAddressIndex = 0;
                      }
                      return allAddresses.get(selectedAddressIndex);
                  }

                  int getTotalItemsCount() {
                      int sum = 0;
                      for (StoreCartModel c : carts) {
                          for (CartItemModel item : c.items) {
                              sum += item.quantity;
                          }
                      }
                      return sum;
                  }
              }

              @SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
              @Override
              protected void onCreate(Bundle savedInstanceState) {
                  super.onCreate(savedInstanceState);
                  requestWindowFeature(Window.FEATURE_NO_TITLE);

                  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                      getWindow().setStatusBarColor(Color.parseColor(COLOR_BG_MAIN));
                      getWindow().setNavigationBarColor(Color.parseColor(COLOR_BG_MAIN));
                  }

                  requestLocationPermissionsIfNeeded();

                  LinearLayout root = new LinearLayout(this);
                  root.setOrientation(LinearLayout.VERTICAL);
                  root.setBackgroundColor(Color.parseColor(COLOR_BG_MAIN));
                  root.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);

                  // ==========================================
                  // ۱. نوار هدر بالا
                  // ==========================================
                  LinearLayout topBar = new LinearLayout(this);
                  topBar.setOrientation(LinearLayout.HORIZONTAL);
                  topBar.setGravity(Gravity.CENTER_VERTICAL);
                  topBar.setBackgroundColor(Color.parseColor(COLOR_BG_CARD));
                  topBar.setPadding(dp(14), dp(10), dp(14), dp(10));

                  TextView titleView = new TextView(this);
                  titleView.setText("🛒 کلونر هوشمند تپسی مارکت");
                  titleView.setTextColor(Color.parseColor(COLOR_ACCENT));
                  titleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
                  titleView.setTypeface(Typeface.DEFAULT_BOLD);

                  statusBadge = new TextView(this);
                  statusBadge.setText("آماده دریافت لیست لایسنس‌ها");
                  statusBadge.setTextColor(Color.parseColor(COLOR_TEXT_MUTED));
                  statusBadge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11);
                  statusBadge.setSingleLine(true);
                  statusBadge.setEllipsize(TextUtils.TruncateAt.END);
                  GradientDrawable badgeBg = new GradientDrawable();
                  badgeBg.setColor(Color.parseColor(COLOR_BG_INPUT));
                  badgeBg.setCornerRadius(dp(10));
                  badgeBg.setStroke(dp(1), Color.parseColor(COLOR_BORDER));
                  statusBadge.setBackground(badgeBg);
                  statusBadge.setPadding(dp(10), dp(4), dp(10), dp(4));
                  LinearLayout.LayoutParams badgeParams = new LinearLayout.LayoutParams(
                          0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
                  badgeParams.setMargins(dp(8), 0, dp(8), 0);
                  statusBadge.setLayoutParams(badgeParams);

                  toggleWebViewBtn = createSmallButton("👁 مرورگر", COLOR_BG_INPUT, COLOR_TEXT_MAIN);
                  toggleWebViewBtn.setOnClickListener(v -> {
                      if (webViewContainer.getVisibility() == View.VISIBLE) {
                          webViewContainer.setVisibility(View.GONE);
                          toggleWebViewBtn.setText("👁 مرورگر");
                      } else {
                          webViewContainer.setVisibility(View.VISIBLE);
                          toggleWebViewBtn.setText("🙈 مخفی");
                      }
                  });

                  topBar.addView(titleView);
                  topBar.addView(statusBadge);
                  topBar.addView(toggleWebViewBtn);
                  root.addView(topBar);

                  progressBar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
                  progressBar.setMax(100);
                  progressBar.setProgress(0);
                  progressBar.setLayoutParams(new LinearLayout.LayoutParams(
                          ViewGroup.LayoutParams.MATCH_PARENT, dp(3)));
                  progressBar.setVisibility(View.GONE);
                  root.addView(progressBar);

                  // ==========================================
                  // ۲. اسکرول اصلی صفحه
                  // ==========================================
                  ScrollView mainScroll = new ScrollView(this);
                  mainScroll.setFillViewport(true);
                  mainScroll.setLayoutParams(new LinearLayout.LayoutParams(
                          ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));

                  LinearLayout contentLayout = new LinearLayout(this);
                  contentLayout.setOrientation(LinearLayout.VERTICAL);
                  contentLayout.setPadding(dp(12), dp(10), dp(12), dp(12));

                  // ------------------------------------------
                  // کارت ۱: ورود لیست لایسنس‌ها
                  // ------------------------------------------
                  LinearLayout inputCard = createCardLayout();

                  LinearLayout inputHeader = new LinearLayout(this);
                  inputHeader.setOrientation(LinearLayout.HORIZONTAL);
                  inputHeader.setGravity(Gravity.CENTER_VERTICAL);

                  TextView inputTitle = new TextView(this);
                  inputTitle.setText("🔑 لیست لایسنس‌ها (خط اول = مبدأ، بقیه = مقصد)");
                  inputTitle.setTextColor(Color.parseColor(COLOR_TEXT_MAIN));
                  inputTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
                  inputTitle.setTypeface(Typeface.DEFAULT_BOLD);
                  inputTitle.setLayoutParams(new LinearLayout.LayoutParams(
                          0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

                  Button pasteBtn = createSmallButton("📋 جایگذاری", "#1E3A5F", COLOR_ACCENT);
                  pasteBtn.setOnClickListener(v -> pasteLicensesFromClipboard());

                  Button clearBtn = createSmallButton("🗑 پاک کردن", "#3B1C22", COLOR_ERROR);
                  LinearLayout.LayoutParams clearParams = new LinearLayout.LayoutParams(
                          ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
                  clearParams.setMargins(dp(6), 0, 0, 0);
                  clearBtn.setLayoutParams(clearParams);
                  clearBtn.setOnClickListener(v -> {
                      licensesInput.setText("");
                      cachedSourceData = null;
                      cachedSourceLicenseKey = null;
                      sourcePreviewCard.setVisibility(View.GONE);
                      updateLicenseCountLabel();
                  });

                  inputHeader.addView(inputTitle);
                  inputHeader.addView(pasteBtn);
                  inputHeader.addView(clearBtn);
                  inputCard.addView(inputHeader);

                  licensesInput = new EditText(this);
                  licensesInput.setHint("هر لایسنس را در یک خط وارد کنید...\nمثال:\nTAPSI-SOURCE-1111 (لایسنس اول: مبدأ آدرس و سبد)\nTAPSI-TARGET-2222 (مقصد اول)\nTAPSI-TARGET-3333 (مقصد دوم)");
                  licensesInput.setHintTextColor(Color.parseColor("#64748B"));
                  licensesInput.setTextColor(Color.parseColor(COLOR_TEXT_MAIN));
                  licensesInput.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
                  licensesInput.setTypeface(Typeface.MONOSPACE);
                  licensesInput.setGravity(Gravity.TOP | Gravity.START);
                  licensesInput.setMinLines(4);
                  licensesInput.setMaxLines(7);
                  licensesInput.setPadding(dp(10), dp(8), dp(10), dp(8));
                  GradientDrawable editBg = new GradientDrawable();
                  editBg.setColor(Color.parseColor(COLOR_BG_INPUT));
                  editBg.setCornerRadius(dp(10));
                  editBg.setStroke(dp(1), Color.parseColor(COLOR_BORDER));
                  licensesInput.setBackground(editBg);
                  LinearLayout.LayoutParams editParams = new LinearLayout.LayoutParams(
                          ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
                  editParams.setMargins(0, dp(8), 0, dp(6));
                  licensesInput.setLayoutParams(editParams);
                  licensesInput.addTextChangedListener(new android.text.TextWatcher() {
                      @Override
                      public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
                      @Override
                      public void onTextChanged(CharSequence s, int start, int before, int count) {
                          updateLicenseCountLabel();
                      }
                      @Override
                      public void afterTextChanged(android.text.Editable s) {}
                  });
                  inputCard.addView(licensesInput);

                  licenseCountLabel = new TextView(this);
                  licenseCountLabel.setText("تعداد لایسنس واردشده: ۰");
                  licenseCountLabel.setTextColor(Color.parseColor(COLOR_TEXT_MUTED));
                  licenseCountLabel.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f);
                  inputCard.addView(licenseCountLabel);

                  // چک‌باکس‌های تنظیمات عملیات
                  LinearLayout optionsRow = new LinearLayout(this);
                  optionsRow.setOrientation(LinearLayout.HORIZONTAL);
                  optionsRow.setGravity(Gravity.CENTER_VERTICAL);
                  LinearLayout.LayoutParams optParams = new LinearLayout.LayoutParams(
                          ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
                  optParams.setMargins(0, dp(6), 0, 0);
                  optionsRow.setLayoutParams(optParams);

                  cloneAddressCheck = new CheckBox(this);
                  cloneAddressCheck.setText("ثبت و پیش‌فرض کردن آدرس");
                  cloneAddressCheck.setTextColor(Color.parseColor(COLOR_TEXT_MAIN));
                  cloneAddressCheck.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f);
                  cloneAddressCheck.setChecked(true);
                  cloneAddressCheck.setLayoutParams(new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

                  cloneCartCheck = new CheckBox(this);
                  cloneCartCheck.setText("کپی کامل سبد خرید");
                  cloneCartCheck.setTextColor(Color.parseColor(COLOR_TEXT_MAIN));
                  cloneCartCheck.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f);
                  cloneCartCheck.setChecked(true);
                  cloneCartCheck.setLayoutParams(new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

                  optionsRow.addView(cloneAddressCheck);
                  optionsRow.addView(cloneCartCheck);
                  inputCard.addView(optionsRow);

                  contentLayout.addView(inputCard);

                  // ------------------------------------------
                  // کارت ۲: پیش‌نمایش اطلاعات استخراج‌شده از لایسنس اول
                  // ------------------------------------------
                  sourcePreviewCard = createCardLayout();
                  sourcePreviewCard.setVisibility(View.GONE);
                  LinearLayout.LayoutParams previewMargin = (LinearLayout.LayoutParams) sourcePreviewCard.getLayoutParams();
                  previewMargin.setMargins(0, dp(10), 0, 0);
                  sourcePreviewCard.setLayoutParams(previewMargin);

                  LinearLayout previewHeader = new LinearLayout(this);
                  previewHeader.setOrientation(LinearLayout.HORIZONTAL);
                  previewHeader.setGravity(Gravity.CENTER_VERTICAL);

                  TextView previewTitle = new TextView(this);
                  previewTitle.setText("📦 اطلاعات دریافت‌شده از لایسنس اول (مبدأ)");
                  previewTitle.setTextColor(Color.parseColor(COLOR_SUCCESS));
                  previewTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
                  previewTitle.setTypeface(Typeface.DEFAULT_BOLD);
                  previewTitle.setLayoutParams(new LinearLayout.LayoutParams(
                          0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

                  switchAddressBtn = createSmallButton("🔄 تغییر آدرس مبدأ", "#1E293B", COLOR_WARNING);
                  switchAddressBtn.setVisibility(View.GONE);
                  switchAddressBtn.setOnClickListener(v -> cycleSourceAddress());

                  previewHeader.addView(previewTitle);
                  previewHeader.addView(switchAddressBtn);
                  sourcePreviewCard.addView(previewHeader);

                  sourceAddressText = new TextView(this);
                  sourceAddressText.setTextColor(Color.parseColor(COLOR_TEXT_MAIN));
                  sourceAddressText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
                  sourceAddressText.setPadding(dp(10), dp(8), dp(10), dp(8));
                  GradientDrawable addrBoxBg = new GradientDrawable();
                  addrBoxBg.setColor(Color.parseColor(COLOR_BG_INPUT));
                  addrBoxBg.setCornerRadius(dp(8));
                  sourceAddressText.setBackground(addrBoxBg);
                  LinearLayout.LayoutParams addrBoxParams = new LinearLayout.LayoutParams(
                          ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
                  addrBoxParams.setMargins(0, dp(8), 0, dp(6));
                  sourceAddressText.setLayoutParams(addrBoxParams);
                  sourcePreviewCard.addView(sourceAddressText);

                  sourceCartText = new TextView(this);
                  sourceCartText.setTextColor(Color.parseColor(COLOR_ACCENT));
                  sourceCartText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
                  sourceCartText.setPadding(dp(10), dp(8), dp(10), dp(8));
                  GradientDrawable cartBoxBg = new GradientDrawable();
                  cartBoxBg.setColor(Color.parseColor(COLOR_BG_INPUT));
                  cartBoxBg.setCornerRadius(dp(8));
                  sourceCartText.setBackground(cartBoxBg);
                  sourcePreviewCard.addView(sourceCartText);

                  contentLayout.addView(sourcePreviewCard);

                  // ------------------------------------------
                  // کارت ۳: مرورگر داخلی (برای انجام خودکار SSO تپسی مارکت)
                  // ------------------------------------------
                  webViewContainer = new FrameLayout(this);
                  LinearLayout.LayoutParams wvParams = new LinearLayout.LayoutParams(
                          ViewGroup.LayoutParams.MATCH_PARENT, dp(210));
                  wvParams.setMargins(0, dp(10), 0, 0);
                  webViewContainer.setLayoutParams(wvParams);
                  GradientDrawable wvBorder = new GradientDrawable();
                  wvBorder.setColor(Color.parseColor(COLOR_BG_CARD));
                  wvBorder.setCornerRadius(dp(12));
                  wvBorder.setStroke(dp(1), Color.parseColor(COLOR_ACCENT));
                  webViewContainer.setBackground(wvBorder);
                  webViewContainer.setPadding(dp(2), dp(2), dp(2), dp(2));
                  webViewContainer.setVisibility(View.GONE);

                  webView = new WebView(this);
                  webView.setLayoutParams(new FrameLayout.LayoutParams(
                          ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
                  setupWebView();
                  webViewContainer.addView(webView);
                  contentLayout.addView(webViewContainer);

                  // ------------------------------------------
                  // کارت ۴: گزارش لحظه‌ای عملیات (Live Logs)
                  // ------------------------------------------
                  LinearLayout logCard = createCardLayout();
                  LinearLayout.LayoutParams logCardParams = new LinearLayout.LayoutParams(
                          ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f);
                  logCardParams.setMargins(0, dp(10), 0, 0);
                  logCard.setLayoutParams(logCardParams);
                  logCard.setMinimumHeight(dp(190));

                  LinearLayout logHeader = new LinearLayout(this);
                  logHeader.setOrientation(LinearLayout.HORIZONTAL);
                  logHeader.setGravity(Gravity.CENTER_VERTICAL);

                  TextView logTitle = new TextView(this);
                  logTitle.setText("📜 گزارش لحظه‌ای مراحل اجرا");
                  logTitle.setTextColor(Color.parseColor(COLOR_TEXT_MAIN));
                  logTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
                  logTitle.setTypeface(Typeface.DEFAULT_BOLD);
                  logTitle.setLayoutParams(new LinearLayout.LayoutParams(
                          0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

                  Button copyLogBtn = createSmallButton("📋 کپی گزارش", COLOR_BG_INPUT, COLOR_TEXT_MUTED);
                  copyLogBtn.setOnClickListener(v -> {
                      ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                      cm.setPrimaryClip(ClipData.newPlainText("Cloner Logs", logView.getText().toString()));
                      Toast.makeText(this, "✅ گزارش کپی شد", Toast.LENGTH_SHORT).show();
                  });

                  logHeader.addView(logTitle);
                  logHeader.addView(copyLogBtn);
                  logCard.addView(logHeader);

                  logScrollView = new ScrollView(this);
                  LinearLayout.LayoutParams logScrollParams = new LinearLayout.LayoutParams(
                          ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f);
                  logScrollParams.setMargins(0, dp(8), 0, 0);
                  logScrollView.setLayoutParams(logScrollParams);
                  GradientDrawable logBg = new GradientDrawable();
                  logBg.setColor(Color.parseColor(COLOR_BG_INPUT));
                  logBg.setCornerRadius(dp(8));
                  logScrollView.setBackground(logBg);
                  logScrollView.setPadding(dp(10), dp(8), dp(10), dp(8));

                  logView = new TextView(this);
                  logView.setTextColor(Color.parseColor("#E2E8F0"));
                  logView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f);
                  logView.setTypeface(Typeface.MONOSPACE);
                  logView.setLineSpacing(dp(2), 1.0f);
                  logView.setText("👋 خوش آمدید!\n۱. لیست لایسنس‌ها را در کادر بالا وارد یا جایگذاری کنید.\n۲. اولین لایسنس به عنوان «مبدأ» (برای خواندن آدرس و سبد خرید) و بقیه لایسنس‌ها به عنوان «مقصد» در نظر گرفته می‌شوند.\n۳. روی «🚀 شروع کپی خودکار» بزنید.\n");
                  logScrollView.addView(logView);
                  logCard.addView(logScrollView);

                  contentLayout.addView(logCard);
                  mainScroll.addView(contentLayout);
                  root.addView(mainScroll);

                  // ==========================================
                  // ۳. نوار دکمه‌های عملیات پایین صفحه
                  // ==========================================
                  LinearLayout bottomBar = new LinearLayout(this);
                  bottomBar.setOrientation(LinearLayout.HORIZONTAL);
                  bottomBar.setGravity(Gravity.CENTER_VERTICAL);
                  bottomBar.setBackgroundColor(Color.parseColor(COLOR_BG_CARD));
                  bottomBar.setPadding(dp(10), dp(8), dp(10), dp(10));

                  readSourceBtn = createActionButton("🔍 ۱. بررسی لایسنس اول", "#1E293B", COLOR_ACCENT, COLOR_ACCENT);
                  LinearLayout.LayoutParams readParams = new LinearLayout.LayoutParams(0, dp(46), 0.95f);
                  readParams.setMargins(0, 0, dp(5), 0);
                  readSourceBtn.setLayoutParams(readParams);
                  readSourceBtn.setOnClickListener(v -> startExecution(true));

                  startCloneBtn = createActionButton("🚀 ۲. شروع کپی خودکار همه", COLOR_SUCCESS, "#052E16", null);
                  LinearLayout.LayoutParams cloneParams = new LinearLayout.LayoutParams(0, dp(46), 1.35f);
                  cloneParams.setMargins(dp(5), 0, 0, 0);
                  startCloneBtn.setLayoutParams(cloneParams);
                  startCloneBtn.setOnClickListener(v -> startExecution(false));

                  stopBtn = createActionButton("⏹ توقف", "#3B1C22", COLOR_ERROR, COLOR_ERROR);
                  LinearLayout.LayoutParams stopParams = new LinearLayout.LayoutParams(0, dp(46), 0.6f);
                  stopParams.setMargins(dp(5), 0, 0, 0);
                  stopBtn.setLayoutParams(stopParams);
                  stopBtn.setVisibility(View.GONE);
                  stopBtn.setOnClickListener(v -> {
                      stopRequested.set(true);
                      appendLog("⚠️ درخواست توقف ثبت شد؛ در حال اتمام مرحله جاری...");
                      updateStatus("در حال توقف...", COLOR_WARNING);
                  });

                  bottomBar.addView(readSourceBtn);
                  bottomBar.addView(startCloneBtn);
                  bottomBar.addView(stopBtn);
                  root.addView(bottomBar);

                  setContentView(root);
              }

              // ==========================================
              // تنظیمات WebView و شکارچی توکن Bearer تپسی مارکت
              // ==========================================
              @SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
              private void setupWebView() {
                  WebSettings settings = webView.getSettings();
                  settings.setJavaScriptEnabled(true);
                  settings.setDomStorageEnabled(true);
                  settings.setDatabaseEnabled(true);
                  settings.setGeolocationEnabled(true);
                  settings.setLoadWithOverviewMode(true);
                  settings.setUseWideViewPort(true);
                  settings.setJavaScriptCanOpenWindowsAutomatically(true);
                  settings.setSupportMultipleWindows(false);
                  settings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
                  settings.setUserAgentString(DEFAULT_USER_AGENT);

                  CookieManager cookieManager = CookieManager.getInstance();
                  cookieManager.setAcceptCookie(true);
                  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                      cookieManager.setAcceptThirdPartyCookies(webView, true);
                  }

                  webView.addJavascriptInterface(new ClonerJsBridge(), "ClonerBridge");

                  webView.setWebChromeClient(new WebChromeClient() {
                      @Override
                      public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
                          callback.invoke(origin, true, false);
                      }
                  });

                  webView.setWebViewClient(new WebViewClient() {
                      @Override
                      public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                          if (request != null && request.getUrl() != null) {
                              String url = request.getUrl().toString();
                              Map<String, String> headers = request.getRequestHeaders();
                              if (headers != null && url.contains("tapsi.markets")) {
                                  String sId = headers.get("session-id");
                                  if (sId != null && !sId.isEmpty()) {
                                      capturedSessionId = sId;
                                  }
                                  for (Map.Entry<String, String> entry : headers.entrySet()) {
                                      if ("authorization".equalsIgnoreCase(entry.getKey())) {
                                          String val = entry.getValue();
                                          if (val != null && val.startsWith("Bearer eyJ")) {
                                              String jwt = val.substring(7).trim();
                                              onCandidateJwtFound(jwt, "NativeHeader");
                                          }
                                      }
                                  }
                              }
                          }
                          return super.shouldInterceptRequest(view, request);
                      }

                      @Override
                      public void onPageStarted(WebView view, String url, Bitmap favicon) {
                          super.onPageStarted(view, url, favicon);
                          injectSessionAndHookScript(view);
                      }

                      @Override
                      public void onPageFinished(WebView view, String url) {
                          super.onPageFinished(view, url);
                          CookieManager.getInstance().flush();
                          injectSessionAndHookScript(view);
                      }
                  });
              }

              private class ClonerJsBridge {
                  @JavascriptInterface
                  public void onBearerCaptured(String token, String sessionId, String source) {
                      if (sessionId != null && !sessionId.isEmpty()) {
                          capturedSessionId = sessionId;
                      }
                      if (token != null && !token.isEmpty()) {
                          String clean = token.startsWith("Bearer ") ? token.substring(7).trim() : token.trim();
                          if (clean.startsWith("eyJ")) {
                              onCandidateJwtFound(clean, source);
                          }
                      }
                  }

                  @JavascriptInterface
                  public void onJsLog(String msg) {
                      // برای لاگ‌های دیباگ داخلی در صورت نیاز
                  }
              }

              private synchronized void onCandidateJwtFound(String jwt, String source) {
                  if (capturedBearerToken != null) return;
                  try {
                      JSONObject payload = decodeJwtPayload(jwt);
                      if (payload == null) return;

                      String iss = payload.optString("iss", "");
                      String tenant = payload.optString("tenant", "");
                      String sub = payload.optString("sub", payload.optString("userId", ""));
                      if ((iss.contains("cerberus") || "TapsiMarket".equalsIgnoreCase(tenant)) && !sub.isEmpty()) {
                          capturedBearerToken = jwt;
                          CountDownLatch latch = tokenLatch;
                          if (latch != null) {
                              latch.countDown();
                          }
                      }
                  } catch (Exception ignored) {
                  }
              }

              private void injectSessionAndHookScript(WebView view) {
                  if (view == null) return;
                  final String safeLs = JSONObject.quote(activeLocalStorageRaw != null ? activeLocalStorageRaw : "{}");
                  final String safeStep = JSONObject.quote(activeStepId != null ? activeStepId : "init");

                  String js = "(function() {" +
                          "try {" +
                          "  var host = window.location.hostname || '';" +
                          "  var stepId = " + safeStep + ";" +
                          "  if (host.indexOf('tapsi.cab') !== -1) {" +
                          "    var cabKey = '__cloner_cab_' + stepId;" +
                          "    if (window.sessionStorage.getItem(cabKey) !== '1') {" +
                          "      window.localStorage.clear();" +
                          "      window.sessionStorage.setItem(cabKey, '1');" +
                          "      var raw = " + safeLs + ";" +
                          "      var data = JSON.parse(raw);" +
                          "      if (data && typeof data === 'object') {" +
                          "        for (var k in data) {" +
                          "          if (Object.prototype.hasOwnProperty.call(data, k)) {" +
                          "            window.localStorage.setItem(k, typeof data[k] === 'string' ? data[k] : JSON.stringify(data[k]));" +
                          "          }" +
                          "        }" +
                          "      }" +
                          "    }" +
                          "  } else if (host.indexOf('tapsi.markets') !== -1 || host.indexOf('tapsi.shop') !== -1) {" +
                          "    var mktKey = '__cloner_mkt_' + stepId;" +
                          "    if (window.sessionStorage.getItem(mktKey) !== '1') {" +
                          "      window.localStorage.clear();" +
                          "      window.sessionStorage.setItem(mktKey, '1');" +
                          "    }" +
                          "  }" +
                          "} catch(e) {}" +
                          // قلاب روی XMLHttpRequest و fetch برای شکار آنی هدر Authorization
                          "try {" +
                          "  if (!window.__clonerHooked) {" +
                          "    window.__clonerHooked = true;" +
                          "    var origSetHeader = XMLHttpRequest.prototype.setRequestHeader;" +
                          "    XMLHttpRequest.prototype.setRequestHeader = function(name, value) {" +
                          "      try {" +
                          "        if (name && name.toLowerCase() === 'authorization' && value && value.indexOf('Bearer eyJ') === 0) {" +
                          "          if (window.ClonerBridge) window.ClonerBridge.onBearerCaptured(value, '', 'XHR');" +
                          "        }" +
                          "      } catch(e) {}" +
                          "      return origSetHeader.apply(this, arguments);" +
                          "    };" +
                          "    var origFetch = window.fetch;" +
                          "    if (origFetch) {" +
                          "      window.fetch = function(input, init) {" +
                          "        try {" +
                          "          if (init && init.headers) {" +
                          "            var h = init.headers;" +
                          "            var auth = (h.Authorization || h.authorization || (h.get && h.get('Authorization')));" +
                          "            if (auth && auth.indexOf('Bearer eyJ') === 0 && window.ClonerBridge) {" +
                          "              window.ClonerBridge.onBearerCaptured(auth, '', 'Fetch');" +
                          "            }" +
                          "          }" +
                          "          var urlStr = (typeof input === 'string') ? input : (input && input.url ? input.url : '');" +
                          "          if (urlStr.indexOf('sso-user/auth') !== -1) {" +
                          "            return origFetch.apply(this, arguments).then(function(resp) {" +
                          "              try {" +
                          "                resp.clone().json().then(function(data) {" +
                          "                  if (data && data.existing_sessions && data.existing_sessions.length > 0 && data.current_step_key === 'START') {" +
                          "                    var sid = data.session_id;" +
                          "                    var exId = data.existing_sessions[0].session_id;" +
                          "                    setTimeout(function() {" +
                          "                      origFetch('https://accounts-api.tapsi.ir/api/v1/sso-user/auth', {" +
                          "                        method: 'POST'," +
                          "                        headers: {'Content-Type': 'application/json', 'x-agent': 'v2.2|accounts|WEB|1.1.0||10|||||||||||||||'}," +
                          "                        credentials: 'include'," +
                          "                        body: JSON.stringify({session_id: sid, selected_step_key: 'USE_EXISTING_SESSION', existing_session_id: exId})" +
                          "                      }).then(function(r2){ return r2.json(); }).then(function(d2) {" +
                          "                        if (d2 && d2.redirect_url) window.location.href = d2.redirect_url;" +
                          "                      }).catch(function(){});" +
                          "                    }, 900);" +
                          "                  }" +
                          "                }).catch(function(){});" +
                          "              } catch(e) {}" +
                          "              return resp;" +
                          "            });" +
                          "          }" +
                          "        } catch(e) {}" +
                          "        return origFetch.apply(this, arguments);" +
                          "      };" +
                          "    }" +
                          "    setInterval(function() {" +
                          "      try {" +
                          "        var h = window.location.hostname || '';" +
                          "        if (h.indexOf('tapsi.markets') !== -1) {" +
                          "          for (var i = 0; i < localStorage.length; i++) {" +
                          "            var k = localStorage.key(i);" +
                          "            var v = localStorage.getItem(k) || '';" +
                          "            var m = v.match(/eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+/);" +
                          "            if (m && window.ClonerBridge) window.ClonerBridge.onBearerCaptured(m[0], '', 'LocalStorage');" +
                          "          }" +
                          "        }" +
                          "      } catch(e) {}" +
                          "    }, 600);" +
                          "  }" +
                          "} catch(e) {}" +
                          "})();";

                  view.evaluateJavascript(js, null);
              }

              // ==========================================
              // اجرای فرآیند اصلی (دریافت از لایسنس اول و کپی برای بقیه)
              // ==========================================
              private void startExecution(final boolean onlyReadSource) {
                  if (isRunning.get()) {
                      Toast.makeText(this, "⏳ عملیات در حال اجراست...", Toast.LENGTH_SHORT).show();
                      return;
                  }

                  final List<String> licenses = parseLicensesList();
                  if (licenses.isEmpty()) {
                      Toast.makeText(this, "❌ لطفاً حداقل یک لایسنس وارد کنید", Toast.LENGTH_SHORT).show();
                      return;
                  }

                  if (!onlyReadSource && licenses.size() < 2) {
                      Toast.makeText(this, "⚠️ برای کپی کردن، حداقل ۲ لایسنس (۱ مبدأ + ۱ مقصد) وارد کنید", Toast.LENGTH_LONG).show();
                      return;
                  }

                  final boolean doAddress = cloneAddressCheck.isChecked();
                  final boolean doCart = cloneCartCheck.isChecked();
                  if (!onlyReadSource && !doAddress && !doCart) {
                      Toast.makeText(this, "⚠️ لطفاً حداقل یکی از گزینه‌های «آدرس» یا «سبد خرید» را فعال کنید", Toast.LENGTH_SHORT).show();
                      return;
                  }

                  isRunning.set(true);
                  stopRequested.set(false);
                  setUiRunningState(true);

                  new Thread(() -> {
                      try {
                          String sourceKey = licenses.get(0);
                          appendLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                          appendLog("🟢 مرحله ۱: مراجعه به لایسنس اول (مبدأ): " + maskKey(sourceKey));
                          updateProgress(5);

                          // اگر قبلاً همین لایسنس اول خوانده شده و کاربر آدرس را انتخاب کرده، می‌توانیم از کش استفاده کنیم یا مجدد بخوانیم
                          if (onlyReadSource || cachedSourceData == null || !sourceKey.equals(cachedSourceLicenseKey)) {
                              updateStatus("در حال استخراج اطلاعات لایسنس اول...", COLOR_WARNING);
                              SourceCloneData srcData = fetchSourceLicenseData(sourceKey);
                              if (srcData == null) {
                                  appendLog("❌ عملیات متوقف شد: عدم امکان دریافت اطلاعات از لایسنس اول.");
                                  updateStatus("❌ خطا در لایسنس اول", COLOR_ERROR);
                                  return;
                              }
                              cachedSourceData = srcData;
                              cachedSourceLicenseKey = sourceKey;
                              mainHandler.post(this::updateSourcePreviewUi);
                          } else {
                              appendLog("ℹ️ استفاده از اطلاعات آماده‌شده لایسنس اول (" + maskKey(sourceKey) + ")");
                          }

                          AddressModel selectedAddr = cachedSourceData.getSelectedAddress();
                          appendLog("📍 آدرس مبدأ: " + (selectedAddr != null ? (selectedAddr.cityName + " - " + selectedAddr.address + " (پلاک " + selectedAddr.plaque + "، واحد " + selectedAddr.unit + ")") : "بدون آدرس!"));
                          appendLog("🛒 تعداد سبدهای خرید مبدأ: " + cachedSourceData.carts.size() + " فروشگاه (" + cachedSourceData.getTotalItemsCount() + " کالا)");

                          if (onlyReadSource) {
                              updateProgress(100);
                              updateStatus("✅ اطلاعات لایسنس اول دریافت شد", COLOR_SUCCESS);
                              appendLog("✅ بررسی لایسنس اول با موفقیت به پایان رسید.");
                              return;
                          }

                          if (doAddress && selectedAddr == null) {
                              appendLog("⚠️ هشدار: لایسنس اول هیچ آدرسی ندارد!");
                          }
                          if (doCart && cachedSourceData.carts.isEmpty()) {
                              appendLog("⚠️ هشدار: سبد خرید لایسنس اول خالی است!");
                          }

                          int totalTargets = licenses.size() - 1;
                          int successCount = 0;
                          int failCount = 0;

                          for (int i = 1; i < licenses.size(); i++) {
                              if (stopRequested.get()) {
                                  appendLog("🛑 عملیات توسط کاربر متوقف شد.");
                                  break;
                              }

                              String targetKey = licenses.get(i);
                              int progressBase = 15 + (int) (((i - 1) / (float) totalTargets) * 80);
                              updateProgress(progressBase);

                              appendLog("────────────────────────────────────────");
                              appendLog("🎯 [" + i + "/" + totalTargets + "] پردازش لایسنس مقصد: " + maskKey(targetKey));
                              updateStatus("پردازش لایسنس " + i + " از " + totalTargets + "...", COLOR_ACCENT);

                              boolean ok = applyToTargetLicense(targetKey, i, cachedSourceData, doAddress, doCart);
                              if (ok) {
                                  successCount++;
                                  appendLog("✅ لایسنس مقصد [" + i + "/" + totalTargets + "] با موفقیت تکمیل شد!");
                              } else {
                                  failCount++;
                                  appendLog("❌ خطا در تکمیل لایسنس مقصد [" + i + "/" + totalTargets + "]");
                              }
                          }

                          updateProgress(100);
                          String summary = String.format(Locale.US, "✅ پایان عملیات | موفق: %d | ناموفق: %d", successCount, failCount);
                          updateStatus(summary, failCount == 0 ? COLOR_SUCCESS : COLOR_WARNING);
                          appendLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                          appendLog("🏁 " + summary);

                      } catch (Exception e) {
                          appendLog("❌ خطای غیرمنتظره: " + e.getMessage());
                          updateStatus("❌ خطای سیستمی", COLOR_ERROR);
                      } finally {
                          isRunning.set(false);
                          mainHandler.post(() -> setUiRunningState(false));
                      }
                  }).start();
              }

              // ==========================================
              // دریافت کامل اطلاعات آدرس و سبد خرید از لایسنس اول
              // ==========================================
              private SourceCloneData fetchSourceLicenseData(String licenseKey) {
                  try {
                      appendLog("⏳ ۱/۴ دریافت اطلاعات لایسنس از سرور...");
                      JSONObject licData = fetchLicenseFromServer(licenseKey);
                      if (licData == null) return null;

                      String cookies = extractCookiesString(licData);
                      String localStorage = extractLocalStorageString(licData);

                      appendLog("⏳ ۲/۴ ورود خودکار به تپسی مارکت و دریافت توکن دسترسی...");
                      String bearer = obtainTapsiMarketBearerToken(licenseKey, "src_" + System.currentTimeMillis(), cookies, localStorage);
                      if (bearer == null || bearer.isEmpty()) {
                          appendLog("❌ دریافت توکن تپسی مارکت برای لایسنس اول ناموفق بود.");
                          return null;
                      }

                      JSONObject jwtPayload = decodeJwtPayload(bearer);
                      long customerId = 0;
                      String phone = "";
                      if (jwtPayload != null) {
                          customerId = parseLongSafe(jwtPayload.optString("userId", jwtPayload.optString("sub", "0")));
                          phone = jwtPayload.optString("username", "");
                      }
                      appendLog("🔑 توکن تپسی مارکت دریافت شد (کد مشتری: " + customerId + (phone.isEmpty() ? "" : " | شماره: " + phone) + ")");

                      SourceCloneData result = new SourceCloneData();
                      result.licenseKey = licenseKey;
                      result.customerId = customerId;
                      result.phone = phone;

                      // ۳. دریافت لیست آدرس‌های مشتری
                      appendLog("⏳ ۳/۴ دریافت لیست آدرس‌های لایسنس اول...");
                      String addrUrl = TAPSI_MARKET_GATEWAY + "/api/v1/accounts/userprofile/getcustomeraddresseswithpaging?pageIndex=1&pageSize=15";
                      JSONObject addrResp = httpJsonRequest("GET", addrUrl, bearer, null);
                      if (addrResp != null && addrResp.optBoolean("success", false)) {
                          JSONObject dataObj = addrResp.optJSONObject("data");
                          JSONArray items = dataObj != null ? dataObj.optJSONArray("customerAddressResponseItems") : null;
                          if (items != null) {
                              for (int i = 0; i < items.length(); i++) {
                                  JSONObject it = items.optJSONObject(i);
                                  if (it == null) continue;
                                  AddressModel am = parseAddressItem(it);
                                  result.allAddresses.add(am);
                                  if (am.isDefault) {
                                      result.selectedAddressIndex = result.allAddresses.size() - 1;
                                  }
                                  if (result.customerId == 0 && am.customerId > 0) {
                                      result.customerId = am.customerId;
                                  }
                              }
                          }
                      }

                      appendLog("📍 تعداد آدرس‌های یافت‌شده: " + result.allAddresses.size());

                      // ۴. دریافت فروشگاه‌های اطراف و استخراج سبد خرید
                      appendLog("⏳ ۴/۴ استخراج سبد خرید از فروشگاه‌های اطراف آدرس...");
                      if (!result.allAddresses.isEmpty()) {
                          // ابتدا آدرس پیش‌فرض را بررسی می‌کنیم؛ اگر سبد خریدی نداشت، سایر آدرس‌های کاربر را هم چک می‌کنیم
                          List<Integer> checkOrder = new ArrayList<>();
                          checkOrder.add(result.selectedAddressIndex);
                          for (int i = 0; i < result.allAddresses.size(); i++) {
                              if (i != result.selectedAddressIndex) checkOrder.add(i);
                          }

                          for (int addrIdx : checkOrder) {
                              AddressModel addr = result.allAddresses.get(addrIdx);
                              List<StoreCartModel> foundCarts = fetchCartsForCoordinates(bearer, addr.lat, addr.lng);
                              if (!foundCarts.isEmpty()) {
                                  result.carts = foundCarts;
                                  if (addrIdx != result.selectedAddressIndex) {
                                      result.selectedAddressIndex = addrIdx;
                                      appendLog("ℹ️ سبد خرید فعال روی آدرس «" + addr.cityName + " - " + addr.address + "» پیدا و انتخاب شد.");
                                  }
                                  break;
                              }
                          }
                      } else {
                          // اگر هیچ آدرسی ثبت نشده بود، مختصات پیش‌فرض تهران را بررسی می‌کنیم
                          result.carts = fetchCartsForCoordinates(bearer, 35.701232, 51.344073);
                      }

                      for (StoreCartModel sc : result.carts) {
                          appendLog("🛍 فروشگاه: " + sc.storeName + " (کد " + sc.storeId + ") — " + sc.items.size() + " نوع کالا:");
                          for (CartItemModel item : sc.items) {
                              appendLog("   • " + item.productName + " [کد: " + item.productId + "] × " + item.quantity + " عدد");
                          }
                      }

                      return result;

                  } catch (Exception e) {
                      appendLog("❌ خطا در خواندن لایسنس اول: " + e.getMessage());
                      return null;
                  }
              }

              private List<StoreCartModel> fetchCartsForCoordinates(String bearer, double lat, double lng) {
                  List<StoreCartModel> cartsList = new ArrayList<>();
                  try {
                      String nearbyUrl = String.format(Locale.US,
                              "%s/api/v1/pourya/stores/nearby?latitude=%.6f&longitude=%.6f",
                              TAPSI_MARKET_GATEWAY, lat, lng);
                      JSONObject nearbyResp = httpJsonRequest("GET", nearbyUrl, bearer, null);
                      JSONArray storeIdsArray = new JSONArray();

                      if (nearbyResp != null && nearbyResp.optBoolean("success", false)) {
                          JSONObject data = nearbyResp.optJSONObject("data");
                          JSONArray stores = data != null ? data.optJSONArray("stores") : null;
                          if (stores != null) {
                              for (int i = 0; i < stores.length(); i++) {
                                  JSONObject s = stores.optJSONObject(i);
                                  if (s != null && s.has("storeId")) {
                                      storeIdsArray.put(s.optInt("storeId"));
                                  }
                              }
                          }
                      }

                      if (storeIdsArray.length() == 0) {
                          return cartsList;
                      }

                      String cartUrl = TAPSI_MARKET_GATEWAY + "/api/Basket/v2/ShoppingCart/GetCustomerShoppingCartItems";
                      JSONObject reqBody = new JSONObject();
                      reqBody.put("storeIds", storeIdsArray);
                      reqBody.put("isFromCartPage", false);
                      reqBody.put("cartDetails", false);

                      JSONObject cartResp = httpJsonRequest("POST", cartUrl, bearer, reqBody.toString());
                      if (cartResp != null && cartResp.optBoolean("success", false)) {
                          JSONObject data = cartResp.optJSONObject("data");
                          JSONArray results = data != null ? data.optJSONArray("result") : null;
                          if (results != null) {
                              for (int i = 0; i < results.length(); i++) {
                                  JSONObject cObj = results.optJSONObject(i);
                                  if (cObj == null) continue;
                                  JSONArray itemsArr = cObj.optJSONArray("items");
                                  if (itemsArr == null || itemsArr.length() == 0) continue;

                                  StoreCartModel scm = new StoreCartModel();
                                  scm.storeId = cObj.optInt("storeId", 0);
                                  scm.storeName = cObj.optString("storeName", cObj.optString("storeDisplayName", "فروشگاه " + scm.storeId));
                                  scm.totalOkPrice = cObj.optDouble("totalOkPrice", 0);
                                  scm.deliveryMethod = cObj.optString("deliveryMethod", "Delivery");
                                  if (scm.deliveryMethod == null || scm.deliveryMethod.isEmpty() || "null".equals(scm.deliveryMethod)) {
                                      scm.deliveryMethod = "Delivery";
                                  }

                                  for (int j = 0; j < itemsArr.length(); j++) {
                                      JSONObject it = itemsArr.optJSONObject(j);
                                      if (it == null) continue;
                                      CartItemModel cim = new CartItemModel();
                                      cim.productId = it.optLong("productId", 0);
                                      cim.quantity = it.optInt("quantity", 1);
                                      cim.productName = it.optString("productName", "کالا " + cim.productId);
                                      cim.price = it.optDouble("price", 0);
                                      cim.okPrice = it.optDouble("okPrice", 0);
                                      if (cim.productId > 0 && cim.quantity > 0) {
                                          scm.items.add(cim);
                                      }
                                  }

                                  if (!scm.items.isEmpty()) {
                                      cartsList.add(scm);
                                  }
                              }
                          }
                      }
                  } catch (Exception e) {
                      appendLog("⚠️ خطا در استعلام سبد خرید: " + e.getMessage());
                  }
                  return cartsList;
              }

              // ==========================================
              // اعمال آدرس و سبد خرید روی لایسنس مقصد
              // ==========================================
              private boolean applyToTargetLicense(String targetKey, int index, SourceCloneData sourceData, boolean doAddress, boolean doCart) {
                  try {
                      appendLog("   ⏳ دریافت اطلاعات لایسنس از سرور...");
                      JSONObject licData = fetchLicenseFromServer(targetKey);
                      if (licData == null) return false;

                      String cookies = extractCookiesString(licData);
                      String localStorage = extractLocalStorageString(licData);

                      appendLog("   ⏳ ورود به تپسی مارکت و دریافت توکن لایسنس مقصد...");
                      String bearer = obtainTapsiMarketBearerToken(targetKey, "dst_" + index + "_" + System.currentTimeMillis(), cookies, localStorage);
                      if (bearer == null || bearer.isEmpty()) {
                          appendLog("   ❌ عدم دریافت توکن تپسی مارکت برای لایسنس مقصد.");
                          return false;
                      }

                      JSONObject jwtPayload = decodeJwtPayload(bearer);
                      long targetCustomerId = 0;
                      String targetPhone = "";
                      if (jwtPayload != null) {
                          targetCustomerId = parseLongSafe(jwtPayload.optString("userId", jwtPayload.optString("sub", "0")));
                          targetPhone = jwtPayload.optString("username", "");
                      }

                      // اگر کد مشتری در JWT نبود، از لیست آدرس‌ها استعلام می‌کنیم
                      if (targetCustomerId == 0) {
                          String checkAddrUrl = TAPSI_MARKET_GATEWAY + "/api/v1/accounts/userprofile/getcustomeraddresseswithpaging?pageIndex=1&pageSize=1";
                          JSONObject checkResp = httpJsonRequest("GET", checkAddrUrl, bearer, null);
                          if (checkResp != null && checkResp.optBoolean("success", false)) {
                              JSONObject d = checkResp.optJSONObject("data");
                              JSONArray arr = d != null ? d.optJSONArray("customerAddressResponseItems") : null;
                              if (arr != null && arr.length() > 0) {
                                  targetCustomerId = arr.optJSONObject(0).optLong("customerId", 0);
                              }
                          }
                      }

                      appendLog("   🔑 توکن مقصد دریافت شد (مشتری: " + targetCustomerId + (targetPhone.isEmpty() ? "" : " | " + targetPhone) + ")");

                      AddressModel srcAddr = sourceData.getSelectedAddress();

                      // ۱. ایجاد آدرس و تنظیم به عنوان آدرس پیش‌فرض
                      if (doAddress && srcAddr != null) {
                          appendLog("   📍 در حال ثبت آدرس: " + srcAddr.address + "...");
                          String addAddrUrl = TAPSI_MARKET_GATEWAY + "/api/voyager/C/CustomerAccount/AddAddress/";

                          JSONObject addBody = new JSONObject();
                          addBody.put("id", 0);
                          addBody.put("customerId", targetCustomerId);
                          addBody.put("mobilePhone", srcAddr.mobilePhone != null ? srcAddr.mobilePhone : "");
                          addBody.put("ShoppingSectorPartId", srcAddr.sectorPartIdStr != null ? srcAddr.sectorPartIdStr : "0");
                          addBody.put("shoppingSectorId", srcAddr.sectorIdStr != null ? srcAddr.sectorIdStr : "0");
                          addBody.put("plaque", srcAddr.plaque != null && !srcAddr.plaque.isEmpty() ? srcAddr.plaque : "0");
                          addBody.put("unit", srcAddr.unit != null && !srcAddr.unit.isEmpty() ? srcAddr.unit : "0");
                          addBody.put("lat", srcAddr.lat);
                          addBody.put("lng", srcAddr.lng);
                          addBody.put("title", srcAddr.title != null && !srcAddr.title.isEmpty() ? srcAddr.title : JSONObject.NULL);
                          addBody.put("addressTypeId", srcAddr.addressTypeId);
                          addBody.put("oprationDuration", 12500);
                          addBody.put("address", srcAddr.address);
                          addBody.put("mapPlatform", "ParsiMap");

                          JSONObject addResp = httpJsonRequest("POST", addAddrUrl, bearer, addBody.toString());
                          if (addResp != null && addResp.optBoolean("success", false)) {
                              long newAddressId = addResp.optLong("data", 0);
                              appendLog("   ✅ آدرس ثبت شد (کد آدرس جدید: " + newAddressId + ")");

                              if (newAddressId > 0) {
                                  String setDefUrl = TAPSI_MARKET_GATEWAY + "/api/voyager/C/CustomerAccount/SetDefaultAddress/" + newAddressId + "/";
                                  JSONObject defResp = httpJsonRequest("POST", setDefUrl, bearer, "{}");
                                  if (defResp != null && defResp.optBoolean("success", false)) {
                                      appendLog("   ✅ آدرس جدید به عنوان پیش‌فرض فعال شد.");
                                  }
                              }
                          } else {
                              String errMsg = addResp != null ? addResp.optString("message", "نامشخص") : "خطای شبکه";
                              appendLog("   ⚠️ ثبت آدرس پاسخ داد: " + errMsg);
                          }

                          // فراخوانی فروشگاه‌های اطراف آدرس جدید برای همگام‌سازی موقعیت در سرور
                          String nearbyUrl = String.format(Locale.US,
                                  "%s/api/v1/pourya/stores/nearby?latitude=%.6f&longitude=%.6f",
                                  TAPSI_MARKET_GATEWAY, srcAddr.lat, srcAddr.lng);
                          httpJsonRequest("GET", nearbyUrl, bearer, null);
                      }

                      // ۲. ایجاد سبد خرید و افزودن تمام کالاها
                      if (doCart && !sourceData.carts.isEmpty()) {
                          for (StoreCartModel cart : sourceData.carts) {
                              appendLog("   🛒 افزودن کالاهای فروشگاه «" + cart.storeName + "» (کد " + cart.storeId + ")...");
                              for (CartItemModel item : cart.items) {
                                  if (stopRequested.get()) return false;
                                  boolean itemAdded = addItemToTargetCart(bearer, cart.storeId, cart.deliveryMethod, item);
                                  if (itemAdded) {
                                      appendLog("      ✔ " + item.productName + " (×" + item.quantity + ") اضافه شد");
                                  } else {
                                      appendLog("      ✖ خطا در افزودن: " + item.productName);
                                  }
                              }
                          }
                      }

                      return true;

                  } catch (Exception e) {
                      appendLog("   ❌ خطا در پردازش لایسنس مقصد: " + e.getMessage());
                      return false;
                  }
              }

              private boolean addItemToTargetCart(String bearer, int storeId, String deliveryMethod, CartItemModel item) {
                  try {
                      String addUrl = TAPSI_MARKET_GATEWAY + "/api/Basket/v2/ShoppingCart/add-item-return-cart";
                      String fallbackUrl = TAPSI_MARKET_GATEWAY + "/api/Basket/v2/ShoppingCart/AddToShoppingCart";

                      JSONObject payload = new JSONObject();
                      payload.put("storeId", storeId);
                      payload.put("productId", item.productId);
                      payload.put("quantity", item.quantity);
                      payload.put("isSupplier", false);
                      payload.put("replaceItemMethodCode", -1);
                      payload.put("sectorId", "0");
                      payload.put("sectorPartId", "0");
                      payload.put("productStoreId", "0");
                      payload.put("deliveryMethod", deliveryMethod != null ? deliveryMethod : "Delivery");
                      payload.put("isMultiStore", true);

                      JSONObject resp = httpJsonRequest("POST", addUrl, bearer, payload.toString());
                      if (resp == null || !resp.optBoolean("success", false)) {
                          // تلاش با اندپوینت دوم (AddToShoppingCart)
                          resp = httpJsonRequest("POST", fallbackUrl, bearer, payload.toString());
                          if (resp == null || !resp.optBoolean("success", false)) {
                              return false;
                          }
                      }

                      // بررسی تعداد واقعی ثبت‌شده در سبد خرید؛ اگر سرور با هر بار فراخوانی ۱ عدد اضافه کرده باشد، مابقی تعداد را تکمیل می‌کنیم
                      int currentQtyInCart = getProductQuantityFromCartResponse(resp, item.productId);
                      int safetyCounter = 0;
                      while (currentQtyInCart > 0 && currentQtyInCart < item.quantity && safetyCounter < 20) {
                          safetyCounter++;
                          JSONObject stepPayload = new JSONObject(payload.toString());
                          stepPayload.put("quantity", 1);
                          JSONObject nextResp = httpJsonRequest("POST", addUrl, bearer, stepPayload.toString());
                          if (nextResp == null || !nextResp.optBoolean("success", false)) {
                              break;
                          }
                          int updatedQty = getProductQuantityFromCartResponse(nextResp, item.productId);
                          if (updatedQty <= currentQtyInCart) {
                              break; // به سقف مجاز خرید (maxOrderLimit) رسیده‌ایم
                          }
                          currentQtyInCart = updatedQty;
                      }

                      return true;
                  } catch (Exception e) {
                      return false;
                  }
              }

              private int getProductQuantityFromCartResponse(JSONObject resp, long targetProductId) {
                  if (resp == null) return -1;
                  JSONObject data = resp.optJSONObject("data");
                  if (data == null) return -1;
                  JSONObject cart = data.optJSONObject("cart");
                  JSONArray items = cart != null ? cart.optJSONArray("items") : data.optJSONArray("items");
                  if (items == null) return -1;
                  for (int i = 0; i < items.length(); i++) {
                      JSONObject it = items.optJSONObject(i);
                      if (it != null && it.optLong("productId", 0) == targetProductId) {
                          return it.optInt("quantity", 1);
                      }
                  }
                  return -1;
              }

              // ==========================================
              // دریافت توکن Bearer تپسی مارکت برای هر لایسنس (از داده‌های لایسنس یا SSO مرورگر)
              // ==========================================
              private String obtainTapsiMarketBearerToken(String licenseKey, String stepId, String cookiesRaw, String localStorageRaw) {
                  // ۱. ابتدا بررسی می‌کنیم آیا توکن معتبر TapsiMarket از قبل داخل کوکی‌ها یا localStorage لایسنس وجود دارد یا خیر
                  String directJwt = findValidMarketJwtInStrings(cookiesRaw, localStorageRaw);
                  if (directJwt != null) {
                      return directJwt;
                  }

                  // ۲. در غیر این صورت، نشست WebView را کاملاً پاک‌سازی کرده و SSO تپسی مارکت را اجرا می‌کنیم
                  capturedBearerToken = null;
                  activeStepId = stepId;
                  activeLicenseKey = licenseKey;
                  activeCookiesRaw = cookiesRaw;
                  activeLocalStorageRaw = localStorageRaw;
                  tokenLatch = new CountDownLatch(1);

                  final CountDownLatch initLatch = new CountDownLatch(1);
                  mainHandler.post(() -> {
                      try {
                          webView.stopLoading();
                          WebStorage.getInstance().deleteAllData();
                          CookieManager cm = CookieManager.getInstance();
                          cm.removeAllCookies(v -> {
                              setCookiesForAllTargetDomains(cm, cookiesRaw);
                              cm.flush();
                              webView.clearCache(true);
                              webView.loadUrl(TAPSI_MARKET_AUTH_URL);
                              initLatch.countDown();
                          });
                      } catch (Exception e) {
                          initLatch.countDown();
                      }
                  });

                  try {
                      initLatch.await(6, TimeUnit.SECONDS);
                      // منتظر شکار توکن Bearer تا ۱۸ ثانیه می‌مانیم
                      boolean captured = tokenLatch.await(18, TimeUnit.SECONDS);
                      if (!captured && capturedBearerToken == null && !stopRequested.get()) {
                          // تلاش دوم: بارگذاری صفحه اول تپسی و سپس هدایت به تپسی مارکت
                          appendLog("   🔄 تلاش مجدد همگام‌سازی SSO از مسیر سوپراپ تپسی...");
                          mainHandler.post(() -> webView.loadUrl("https://app.tapsi.cab"));
                          Thread.sleep(3000);
                          mainHandler.post(() -> webView.loadUrl(TAPSI_MARKET_AUTH_URL));
                          tokenLatch.await(15, TimeUnit.SECONDS);
                      }
                  } catch (InterruptedException ignored) {
                  }

                  return capturedBearerToken;
              }

              private void setCookiesForAllTargetDomains(CookieManager cm, String cookiesRaw) {
                  if (cookiesRaw == null || cookiesRaw.trim().isEmpty()) return;
                  String[] parts = cookiesRaw.split(";");
                  for (String domain : TARGET_DOMAINS) {
                      String host = domain.startsWith(".") ? domain.substring(1) : domain;
                      String url = "https://" + host;
                      for (String part : parts) {
                          String trimmed = part.trim();
                          if (trimmed.isEmpty()) continue;
                          int eq = trimmed.indexOf('=');
                          if (eq <= 0) continue;
                          String name = trimmed.substring(0, eq).trim();
                          String value = trimmed.substring(eq + 1).trim();
                          if (RESERVED_COOKIE_ATTRS.contains(name.toLowerCase(Locale.US))) continue;

                          String cookieHeader = name + "=" + value + "; Domain=" + domain + "; Path=/; Secure";
                          cm.setCookie(url, cookieHeader);
                          cm.setCookie(url, name + "=" + value + "; Path=/; Secure");
                      }
                  }
              }

              private String findValidMarketJwtInStrings(String... sources) {
                  long nowSec = System.currentTimeMillis() / 1000L;
                  for (String src : sources) {
                      if (src == null || !src.contains("eyJ")) continue;
                      java.util.regex.Matcher m = java.util.regex.Pattern
                              .compile("eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+")
                              .matcher(src);
                      while (m.find()) {
                          String candidate = m.group();
                          JSONObject payload = decodeJwtPayload(candidate);
                          if (payload != null) {
                              String iss = payload.optString("iss", "");
                              String tenant = payload.optString("tenant", "");
                              long exp = payload.optLong("exp", 0);
                              if ((iss.contains("cerberus") || "TapsiMarket".equalsIgnoreCase(tenant))
                                      && (exp == 0 || exp > nowSec + 60)) {
                                  return candidate;
                              }
                          }
                      }
                  }
                  return null;
              }

              // ==========================================
              // ارتباط شبکه با سرور لایسنس و درگاه تپسی مارکت
              // ==========================================
              private JSONObject fetchLicenseFromServer(String licenseKey) {
                  HttpURLConnection conn = null;
                  try {
                      String encodedKey = URLEncoder.encode(licenseKey.trim(), "UTF-8");
                      URL url = new URL(LICENSE_API_BASE + encodedKey);
                      conn = (HttpURLConnection) url.openConnection();
                      conn.setRequestMethod("GET");
                      conn.setConnectTimeout(20000);
                      conn.setReadTimeout(20000);
                      conn.setRequestProperty("Accept", "application/json");

                      int code = conn.getResponseCode();
                      String respStr = readStream(code >= 200 && code < 400 ? conn.getInputStream() : conn.getErrorStream());
                      JSONObject json = new JSONObject(respStr);
                      if (code == 200 && json.optBoolean("success", false)) {
                          JSONObject data = json.optJSONObject("data");
                          return data != null ? data : json;
                      } else {
                          String msg = json.optString("message", json.optString("detail", "کلید نامعتبر است"));
                          appendLog("   ❌ خطای سرور لایسنس: " + msg);
                          return null;
                      }
                  } catch (Exception e) {
                      appendLog("   ❌ خطا در دریافت لایسنس: " + e.getMessage());
                      return null;
                  } finally {
                      if (conn != null) conn.disconnect();
                  }
              }

              private JSONObject httpJsonRequest(String method, String urlStr, String bearerToken, String jsonBody) {
                  HttpURLConnection conn = null;
                  try {
                      URL url = new URL(urlStr);
                      conn = (HttpURLConnection) url.openConnection();
                      conn.setRequestMethod(method);
                      conn.setConnectTimeout(20000);
                      conn.setReadTimeout(20000);

                      conn.setRequestProperty("Accept", "application/json, text/plain, */*");
                      conn.setRequestProperty("Content-Type", "application/json");
                      conn.setRequestProperty("X-Skip-Authorization", "false");
                      conn.setRequestProperty("X-Correlation-Id", UUID.randomUUID().toString());
                      conn.setRequestProperty("session-id", capturedSessionId != null ? capturedSessionId : UUID.randomUUID().toString());
                      conn.setRequestProperty("advertising_id", "");
                      conn.setRequestProperty("ui-version", "2.0");
                      conn.setRequestProperty("source", "tapsiMarket");
                      conn.setRequestProperty("Origin", "https://www.tapsi.markets");
                      conn.setRequestProperty("Referer", "https://www.tapsi.markets/");
                      conn.setRequestProperty("User-Agent", DEFAULT_USER_AGENT);

                      if (bearerToken != null && !bearerToken.isEmpty()) {
                          conn.setRequestProperty("Authorization", "Bearer " + bearerToken);
                      }

                      if (jsonBody != null && ("POST".equalsIgnoreCase(method) || "PUT".equalsIgnoreCase(method))) {
                          conn.setDoOutput(true);
                          byte[] bytes = jsonBody.getBytes(StandardCharsets.UTF_8);
                          try (OutputStream os = conn.getOutputStream()) {
                              os.write(bytes, 0, bytes.length);
                          }
                      }

                      int code = conn.getResponseCode();
                      if (code == 204) {
                          JSONObject emptyOk = new JSONObject();
                          emptyOk.put("success", true);
                          return emptyOk;
                      }

                      String resp = readStream(code >= 200 && code < 400 ? conn.getInputStream() : conn.getErrorStream());
                      if (resp == null || resp.trim().isEmpty()) {
                          JSONObject resObj = new JSONObject();
                          resObj.put("success", code >= 200 && code < 300);
                          return resObj;
                      }
                      return new JSONObject(resp);
                  } catch (Exception e) {
                      return null;
                  } finally {
                      if (conn != null) conn.disconnect();
                  }
              }

              // ==========================================
              // توابع کمکی پردازش JSON و رابط کاربری
              // ==========================================
              private AddressModel parseAddressItem(JSONObject it) {
                  AddressModel am = new AddressModel();
                  am.id = it.optLong("id", 0);
                  am.address = it.optString("address", "");
                  am.cityName = it.optString("cityName", "");
                  am.cityId = it.optInt("cityId", 0);
                  am.customerId = it.optLong("customerId", 0);
                  am.isDefault = it.optBoolean("isDefault", false);
                  am.lat = it.optDouble("lat", 0);
                  am.lng = it.optDouble("lng", 0);
                  am.plaque = it.isNull("plaque") ? "0" : it.optString("plaque", "0");
                  am.unit = it.isNull("unit") ? "0" : it.optString("unit", "0");
                  am.title = it.isNull("title") ? null : it.optString("title", null);
                  am.addressTypeId = it.optInt("addressTypeId", 3);
                  am.sectorIdStr = it.isNull("sectorId") ? "0" : String.valueOf(it.opt("sectorId"));
                  am.sectorPartIdStr = it.isNull("sectorPartId") ? "0" : String.valueOf(it.opt("sectorPartId"));
                  am.mobilePhone = it.isNull("mobilePhone") ? "" : it.optString("mobilePhone", "");
                  return am;
              }

              private void updateSourcePreviewUi() {
                  if (cachedSourceData == null) {
                      sourcePreviewCard.setVisibility(View.GONE);
                      return;
                  }
                  sourcePreviewCard.setVisibility(View.VISIBLE);

                  if (cachedSourceData.allAddresses.size() > 1) {
                      switchAddressBtn.setVisibility(View.VISIBLE);
                      switchAddressBtn.setText("🔄 تغییر آدرس (" + (cachedSourceData.selectedAddressIndex + 1) + "/" + cachedSourceData.allAddresses.size() + ")");
                  } else {
                      switchAddressBtn.setVisibility(View.GONE);
                  }

                  AddressModel addr = cachedSourceData.getSelectedAddress();
                  if (addr != null) {
                      sourceAddressText.setText(String.format(Locale.US,
                              "📍 آدرس انتخابی: %s — %s\nپلاک: %s | واحد: %s | مختصات: %.5f, %.5f",
                              addr.cityName, addr.address, addr.plaque, addr.unit, addr.lat, addr.lng));
                  } else {
                      sourceAddressText.setText("📍 هیچ آدرسی در لایسنس اول یافت نشد.");
                  }

                  if (!cachedSourceData.carts.isEmpty()) {
                      StringBuilder sb = new StringBuilder();
                      for (int i = 0; i < cachedSourceData.carts.size(); i++) {
                          StoreCartModel c = cachedSourceData.carts.get(i);
                          if (i > 0) sb.append("\n\n");
                          sb.append("🏪 ").append(c.storeName).append(" (کد ").append(c.storeId).append("):");
                          for (CartItemModel item : c.items) {
                              sb.append("\n  • ").append(item.productName).append(" × ").append(item.quantity).append(" عدد");
                          }
                      }
                      sourceCartText.setText(sb.toString());
                  } else {
                      sourceCartText.setText("🛒 سبد خرید لایسنس اول خالی است.");
                  }
              }

              private void cycleSourceAddress() {
                  if (cachedSourceData == null || cachedSourceData.allAddresses.size() <= 1) return;
                  if (isRunning.get()) return;

                  cachedSourceData.selectedAddressIndex =
                          (cachedSourceData.selectedAddressIndex + 1) % cachedSourceData.allAddresses.size();
                  updateSourcePreviewUi();
                  AddressModel newlySelected = cachedSourceData.getSelectedAddress();
                  if (newlySelected != null) {
                      appendLog("🔄 آدرس مبدأ تغییر یافت به: " + newlySelected.cityName + " - " + newlySelected.address);
                  }
              }

              private String extractCookiesString(JSONObject dataObj) {
                  Object raw = dataObj.opt("cookies");
                  if (raw instanceof String) {
                      return (String) raw;
                  } else if (raw instanceof JSONObject) {
                      JSONObject map = (JSONObject) raw;
                      List<String> pairs = new ArrayList<>();
                      java.util.Iterator<String> keys = map.keys();
                      while (keys.hasNext()) {
                          String k = keys.next();
                          pairs.add(k + "=" + map.optString(k, ""));
                      }
                      return TextUtils.join("; ", pairs);
                  }
                  return "";
              }

              private String extractLocalStorageString(JSONObject dataObj) {
                  Object raw = dataObj.opt("local_storage");
                  if (raw instanceof String && !((String) raw).trim().isEmpty()) {
                      return (String) raw;
                  } else if (raw instanceof JSONObject) {
                      return raw.toString();
                  }
                  return "{}";
              }

              private JSONObject decodeJwtPayload(String jwt) {
                  try {
                      String[] parts = jwt.split("\\.");
                      if (parts.length < 2) return null;
                      byte[] decoded = Base64.decode(parts[1], Base64.URL_SAFE | Base64.NO_PADDING | Base64.NO_WRAP);
                      String jsonStr = new String(decoded, StandardCharsets.UTF_8);
                      return new JSONObject(jsonStr);
                  } catch (Exception e) {
                      return null;
                  }
              }

              private long parseLongSafe(String s) {
                  try {
                      return Long.parseLong(s.trim());
                  } catch (Exception e) {
                      return 0;
                  }
              }

              private String readStream(InputStream is) throws Exception {
                  if (is == null) return "";
                  StringBuilder sb = new StringBuilder();
                  try (BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
                      String line;
                      while ((line = br.readLine()) != null) {
                          sb.append(line);
                      }
                  }
                  return sb.toString();
              }

              private List<String> parseLicensesList() {
                  String raw = licensesInput.getText() != null ? licensesInput.getText().toString() : "";
                  String[] tokens = raw.split("[\\r\\n,;\\s]+");
                  Set<String> unique = new LinkedHashSet<>();
                  for (String t : tokens) {
                      String clean = t.trim();
                      if (!clean.isEmpty()) {
                          unique.add(clean);
                      }
                  }
                  return new ArrayList<>(unique);
              }

              private void updateLicenseCountLabel() {
                  List<String> list = parseLicensesList();
                  int count = list.size();
                  if (count == 0) {
                      licenseCountLabel.setText("تعداد لایسنس واردشده: ۰");
                      licenseCountLabel.setTextColor(Color.parseColor(COLOR_TEXT_MUTED));
                  } else if (count == 1) {
                      licenseCountLabel.setText("تعداد لایسنس: ۱ (فقط لایسنس اول/مبدأ — برای کپی حداقل ۱ لایسنس مقصد هم اضافه کنید)");
                      licenseCountLabel.setTextColor(Color.parseColor(COLOR_WARNING));
                  } else {
                      licenseCountLabel.setText("تعداد کل لایسنس‌ها: " + count + " (۱ لایسنس مبدأ + " + (count - 1) + " لایسنس مقصد)");
                      licenseCountLabel.setTextColor(Color.parseColor(COLOR_SUCCESS));
                  }
              }

              private void pasteLicensesFromClipboard() {
                  ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                  if (clipboard != null && clipboard.hasPrimaryClip()) {
                      ClipData.Item item = clipboard.getPrimaryClip().getItemAt(0);
                      CharSequence text = item != null ? item.getText() : null;
                      if (text != null && text.length() > 0) {
                          String current = licensesInput.getText().toString().trim();
                          if (current.isEmpty()) {
                              licensesInput.setText(text.toString().trim());
                          } else {
                              licensesInput.setText(current + "\n" + text.toString().trim());
                          }
                          updateLicenseCountLabel();
                          Toast.makeText(this, "✅ لایسنس‌ها اضافه شدند", Toast.LENGTH_SHORT).show();
                          return;
                      }
                  }
                  Toast.makeText(this, "⚠️ کلیپ‌بورد خالی است", Toast.LENGTH_SHORT).show();
              }

              private String maskKey(String key) {
                  if (key == null || key.length() <= 10) return key;
                  return key.substring(0, 6) + "..." + key.substring(key.length() - 4);
              }

              private void appendLog(final String message) {
                  mainHandler.post(() -> {
                      logView.append("\n" + message);
                      logScrollView.post(() -> logScrollView.fullScroll(View.FOCUS_DOWN));
                  });
              }

              private void updateStatus(final String text, final String colorHex) {
                  mainHandler.post(() -> {
                      statusBadge.setText(text);
                      statusBadge.setTextColor(Color.parseColor(colorHex));
                  });
              }

              private void updateProgress(final int percent) {
                  mainHandler.post(() -> {
                      progressBar.setVisibility(View.VISIBLE);
                      progressBar.setProgress(percent);
                  });
              }

              private void setUiRunningState(boolean running) {
                  readSourceBtn.setEnabled(!running);
                  startCloneBtn.setEnabled(!running);
                  licensesInput.setEnabled(!running);
                  stopBtn.setVisibility(running ? View.VISIBLE : View.GONE);
                  if (!running) {
                      progressBar.setVisibility(View.GONE);
                  }
              }

              private LinearLayout createCardLayout() {
                  LinearLayout card = new LinearLayout(this);
                  card.setOrientation(LinearLayout.VERTICAL);
                  card.setPadding(dp(12), dp(12), dp(12), dp(12));
                  GradientDrawable bg = new GradientDrawable();
                  bg.setColor(Color.parseColor(COLOR_BG_CARD));
                  bg.setCornerRadius(dp(14));
                  bg.setStroke(dp(1), Color.parseColor(COLOR_BORDER));
                  card.setBackground(bg);
                  card.setLayoutParams(new LinearLayout.LayoutParams(
                          ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
                  return card;
              }

              private Button createActionButton(String text, String bgHex, String textHex, String strokeHex) {
                  Button btn = new Button(this);
                  btn.setText(text);
                  btn.setAllCaps(false);
                  btn.setTextColor(Color.parseColor(textHex));
                  btn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f);
                  btn.setTypeface(Typeface.DEFAULT_BOLD);
                  btn.setSingleLine(true);

                  GradientDrawable bg = new GradientDrawable();
                  bg.setColor(Color.parseColor(bgHex));
                  bg.setCornerRadius(dp(10));
                  if (strokeHex != null) {
                      bg.setStroke(dp(1), Color.parseColor(strokeHex));
                  }
                  btn.setBackground(bg);
                  btn.setPadding(dp(8), 0, dp(8), 0);
                  return btn;
              }

              private Button createSmallButton(String text, String bgHex, String textHex) {
                  Button btn = new Button(this);
                  btn.setText(text);
                  btn.setAllCaps(false);
                  btn.setTextColor(Color.parseColor(textHex));
                  btn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11);

                  GradientDrawable bg = new GradientDrawable();
                  bg.setColor(Color.parseColor(bgHex));
                  bg.setCornerRadius(dp(8));
                  bg.setStroke(dp(1), Color.parseColor(COLOR_BORDER));
                  btn.setBackground(bg);
                  btn.setPadding(dp(10), dp(4), dp(10), dp(4));
                  btn.setMinHeight(0);
                  btn.setMinimumHeight(0);
                  btn.setMinWidth(0);
                  btn.setMinimumWidth(0);
                  return btn;
              }

              private int dp(int value) {
                  return (int) TypedValue.applyDimension(
                          TypedValue.COMPLEX_UNIT_DIP,
                          value,
                          getResources().getDisplayMetrics()
                  );
              }

              private void requestLocationPermissionsIfNeeded() {
                  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                      if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                          requestPermissions(new String[]{
                                  Manifest.permission.ACCESS_FINE_LOCATION,
                                  Manifest.permission.ACCESS_COARSE_LOCATION
                          }, 1002);
                      }
                  }
              }
          }
          EOF

      - name: Build Debug APK with Gradle
        run: |
          gradle assembleDebug --no-daemon

      - name: Prepare Output APK
        run: |
          cp app/build/outputs/apk/debug/app-debug.apk TapsiMarket-Cloner-v1.0.apk

      - name: Upload APK to Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: TapsiMarket-Cloner-APK
          path: TapsiMarket-Cloner-v1.0.apk

      - name: Create GitHub Release (Optional Direct Download)
        uses: softprops/action-gh-release@v2
        if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
        continue-on-error: true
        with:
          tag_name: v1.0.${{ github.run_number }}
          name: "TapsiMarket Cloner APK (Build #${{ github.run_number }})"
          files: TapsiMarket-Cloner-v1.0.apk
