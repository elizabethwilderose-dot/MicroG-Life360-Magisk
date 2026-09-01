package dev.gmsver;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage;

/**
 * Reports a higher com.google.android.gms versionCode to apps that gate on it.
 *
 * microG's real versionCode trails what some apps demand (Life360 wants
 * 254730000, microG 0.3.16 reports 252432032), so the app refuses to talk to
 * Play Services even though microG implements what it needs. This rewrites the
 * number in the hooked process only; microG itself is untouched.
 */
public class Module implements IXposedHookLoadPackage {

    private static final String GMS = "com.google.android.gms";
    private static final int FAKE_VERSION_CODE = 254730000;
    private static final String TAG = "[gms-version-spoof] ";

    /** Set once we have actually rewritten a version, to keep the log to one line. */
    private static boolean reported = false;

    public void handleLoadPackage(XC_LoadPackage.LoadPackageParam lpparam) throws Throwable {
        // Never touch Play Services' own process: microG reads its own package
        // info for self-checks and updates, and must see the real version.
        if (GMS.equals(lpparam.packageName) || "com.android.vending".equals(lpparam.packageName)) {
            return;
        }

        ClassLoader cl = lpparam.classLoader;
        XposedBridge.log(TAG + "active in " + lpparam.packageName);

        // Primary: rewrite the versionCode on any PackageInfo the app asks for
        // about com.google.android.gms. This is the value every Play Services
        // client library ultimately compares against its built-in minimum.
        XC_MethodHook bumpVersion = new XC_MethodHook() {
            protected void afterHookedMethod(MethodHookParam param) throws Throwable {
                Object info = param.getResult();
                if (info == null) {
                    return;
                }
                Object requested = (param.args != null && param.args.length > 0) ? param.args[0] : null;
                if (!GMS.equals(requested)) {
                    return;
                }
                XposedHelpers.setIntField(info, "versionCode", FAKE_VERSION_CODE);
                XposedHelpers.setIntField(info, "versionCodeMajor", 0);
                if (!reported) {
                    reported = true;
                    XposedBridge.log(TAG + "rewrote " + GMS + " versionCode -> " + FAKE_VERSION_CODE);
                }
            }
        };

        hook(cl, "android.app.ApplicationPackageManager", "getPackageInfo",
                new Object[] { String.class, int.class }, bumpVersion);
        // Android 13+ overload taking PackageInfoFlags instead of an int.
        hook(cl, "android.app.ApplicationPackageManager", "getPackageInfo",
                new Object[] { String.class, "android.content.pm.PackageManager$PackageInfoFlags" }, bumpVersion);

        // Backstop: if the availability check is reached by some path that does
        // not read PackageInfo, answer SUCCESS (0) directly. These classes are
        // often minified away, so every hook here is best-effort.
        XC_MethodHook reportAvailable = new XC_MethodHook() {
            protected void beforeHookedMethod(MethodHookParam param) throws Throwable {
                param.setResult(Integer.valueOf(0));
            }
        };

        String[] availabilityClasses = {
                "com.google.android.gms.common.GooglePlayServicesUtil",
                "com.google.android.gms.common.GooglePlayServicesUtilLight",
                "com.google.android.gms.common.GoogleApiAvailability",
                "com.google.android.gms.common.GoogleApiAvailabilityLight",
        };
        for (int i = 0; i < availabilityClasses.length; i++) {
            String c = availabilityClasses[i];
            hook(cl, c, "isGooglePlayServicesAvailable",
                    new Object[] { "android.content.Context" }, reportAvailable);
            hook(cl, c, "isGooglePlayServicesAvailable",
                    new Object[] { "android.content.Context", int.class }, reportAvailable);
        }
    }

    /** findAndHookMethod, but a missing class or overload is not fatal. */
    private static void hook(ClassLoader cl, String className, String methodName,
                             Object[] paramTypes, XC_MethodHook callback) {
        try {
            Object[] args = new Object[paramTypes.length + 1];
            System.arraycopy(paramTypes, 0, args, 0, paramTypes.length);
            args[paramTypes.length] = callback;
            XposedHelpers.findAndHookMethod(className, cl, methodName, args);
        } catch (Throwable t) {
            XposedBridge.log(TAG + "skipped " + className + "." + methodName + ": " + t);
        }
    }
}
