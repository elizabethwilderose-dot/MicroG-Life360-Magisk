package de.robv.android.xposed;

/** Compile-only stub. Provided by the Xposed framework at runtime. */
public final class XposedHelpers {

    public static XC_MethodHook.Unhook findAndHookMethod(String className, ClassLoader classLoader,
                                                         String methodName,
                                                         Object... parameterTypesAndCallback) {
        return null;
    }

    public static void setIntField(Object obj, String fieldName, int value) {
    }

    public static void setLongField(Object obj, String fieldName, long value) {
    }
}
