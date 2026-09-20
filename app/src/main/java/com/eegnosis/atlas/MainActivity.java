package com.eegnosis.atlas;

import android.os.Bundle;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import androidx.webkit.WebViewAssetLoader;

import org.json.JSONArray;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

public class MainActivity extends AppCompatActivity {
    private static final String TAG = "EEGnosis";
    private WebView webView;
    private WebViewAssetLoader assetLoader;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        assetLoader = new WebViewAssetLoader.Builder()
            .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this))
            .addPathHandler("/figures/", new WebViewAssetLoader.InternalStoragePathHandler(this,
                new File(getFilesDir(), "figures")))
            .build();

        webView = new WebView(this);
        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setAllowFileAccess(true);
        s.setAllowContentAccess(true);
        s.setLoadWithOverviewMode(true);
        s.setUseWideViewPort(true);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                return assetLoader.shouldInterceptRequest(request.getUrl());
            }
        });

        webView.setWebChromeClient(new WebChromeClient());
        webView.addJavascriptInterface(new JSBridge(), "Android");

        webView.loadUrl("https://appassets.androidplatform.net/assets/index.html");
        setContentView(webView);
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }

    public class JSBridge {

        @JavascriptInterface
        public String getFiguresDir() {
            File dir = new File(getFilesDir(), "figures");
            if (!dir.exists()) dir.mkdirs();
            // استخدام الرابط الوهمي عبر WebViewAssetLoader
            return "https://appassets.androidplatform.net/figures";
        }

        @JavascriptInterface
        public boolean isSectionDownloaded(String sectionId) {
            File flag = new File(getFilesDir(), "figures/.done_" + sectionId);
            return flag.exists();
        }

        @JavascriptInterface
        public String getDownloadedSections() {
            try {
                File dir = getFilesDir();
                JSONArray arr = new JSONArray();
                File[] files = dir.listFiles();
                if (files != null) {
                    for (File f : files) {
                        String name = f.getName();
                        if (name.startsWith(".done_")) {
                            arr.put(name.substring(6));
                        }
                    }
                }
                return arr.toString();
            } catch (Exception e) {
                return "[]";
            }
        }

        @JavascriptInterface
        public void downloadSection(final String sectionId, final String url) {
            new Thread(new Runnable() {
                @Override
                public void run() {
                    try {
                        File cacheDir = new File(getCacheDir(), "dl");
                        if (!cacheDir.exists()) cacheDir.mkdirs();
                        File zipFile = new File(cacheDir, sectionId + ".zip");

                        runOnUiThread(() -> webView.evaluateJavascript(
                            "updateProgress('" + sectionId + "', 0, 'downloading')", null));

                        URL u = new URL(url);
                        HttpURLConnection conn = (HttpURLConnection) u.openConnection();
                        conn.setConnectTimeout(30000);
                        conn.setReadTimeout(60000);
                        conn.connect();

                        int total = conn.getContentLength();
                        InputStream in = new BufferedInputStream(conn.getInputStream());
                        FileOutputStream fos = new FileOutputStream(zipFile);

                        byte[] buf = new byte[8192];
                        int read;
                        long downloaded = 0;
                        int lastPercent = 0;

                        while ((read = in.read(buf)) != -1) {
                            fos.write(buf, 0, read);
                            downloaded += read;
                            if (total > 0) {
                                int percent = (int) ((downloaded * 100) / total);
                                if (percent - lastPercent >= 2) {
                                    lastPercent = percent;
                                    final int p = percent;
                                    runOnUiThread(() -> webView.evaluateJavascript(
                                        "updateProgress('" + sectionId + "', " + p + ", 'downloading')", null));
                                }
                            }
                        }
                        fos.close();
                        in.close();

                        runOnUiThread(() -> webView.evaluateJavascript(
                            "updateProgress('" + sectionId + "', 100, 'extracting')", null));

                        File figuresDir = new File(getFilesDir(), "figures");
                        if (!figuresDir.exists()) figuresDir.mkdirs();

                        unzip(zipFile, figuresDir);
                        zipFile.delete();

                        File flag = new File(figuresDir, ".done_" + sectionId);
                        flag.createNewFile();

                        runOnUiThread(() -> webView.evaluateJavascript(
                            "updateProgress('" + sectionId + "', 100, 'done')", null));

                    } catch (Exception e) {
                        final String msg = e.getMessage();
                        runOnUiThread(() -> webView.evaluateJavascript(
                            "updateProgress('" + sectionId + "', -1, 'error: " + msg + "')", null));
                    }
                }
            }).start();
        }

        @JavascriptInterface
        public void deleteSection(String sectionId) {
            File figuresDir = new File(getFilesDir(), "figures");
            File flag = new File(figuresDir, ".done_" + sectionId);
            if (flag.exists()) flag.delete();
        }

        @JavascriptInterface
        public void showToast(String msg) {
            Toast.makeText(MainActivity.this, msg, Toast.LENGTH_SHORT).show();
        }
    }

    private void unzip(File zipFile, File targetDir) throws Exception {
        ZipInputStream zis = new ZipInputStream(new BufferedInputStream(
            new FileInputStream(zipFile)));
        ZipEntry entry;
        byte[] buffer = new byte[8192];

        while ((entry = zis.getNextEntry()) != null) {
            String name = entry.getName();
            File outFile = new File(targetDir, name);
            if (!outFile.getCanonicalPath().startsWith(targetDir.getCanonicalPath())) {
                continue;
            }
            if (entry.isDirectory()) {
                outFile.mkdirs();
            } else {
                File parent = outFile.getParentFile();
                if (parent != null && !parent.exists()) parent.mkdirs();
                FileOutputStream fos = new FileOutputStream(outFile);
                int len;
                while ((len = zis.read(buffer)) > 0) {
                    fos.write(buffer, 0, len);
                }
                fos.close();
            }
            zis.closeEntry();
        }
        zis.close();
    }
}
