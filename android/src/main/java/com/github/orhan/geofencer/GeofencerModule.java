package com.github.orhan.geofencer;

import android.Manifest;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.util.Log;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import com.google.gson.*;

import com.facebook.react.bridge.*;
import com.facebook.react.modules.core.RCTNativeAppEventEmitter;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public class GeofencerModule extends ReactContextBaseJavaModule {
    public static final String TAG = "RNGeofencer";
    private GeoNotificationManager geoNotificationManager;
    private static ReactContext context;

    @Override
    public String getName() {
        return "Geofencer";
    }

    /**
     * Constructor
     */
    public GeofencerModule(ReactApplicationContext reactContext) {
        super(reactContext);
        context = reactContext;
        Logger.setLogger(new Logger(TAG, context, false));
        geoNotificationManager = new GeoNotificationManager(context);
    }

    private GeoNotification parseFromJSONObject(ReadableMap object) throws Exception {
        GeoNotification geo = GeoNotification.fromJson(toJSONObject(object).toString());
        return geo;
    }

    public static void onTransitionReceived(List<GeoNotification> notifications) {
        Log.d(TAG, "Transition Event Received!");

        WritableArray array = new WritableNativeArray();

        try {
            for (GeoNotification notification : notifications) {
                WritableMap notificationMap = convertJsonToMap(new JSONObject(Gson.get().toJson(notification)));
                array.pushMap(notificationMap);
            }

            context.getJSModule(RCTNativeAppEventEmitter.class).emit("GeofencerOnTransitionReceived", array);
        } catch (Exception e) {
            // EMPTY!
        }
    }

    @ReactMethod
    public void initialize(Callback success, Callback error) {
        try {
            String[] permissions = {
                Manifest.permission.ACCESS_COARSE_LOCATION,
                Manifest.permission.ACCESS_FINE_LOCATION
            };

            if (!hasPermissions(context.getApplicationContext(), permissions)) {
                error.invoke("Permissions not given, request permissions before continuing!");
            } else {
                success.invoke();
            }
        } catch(Exception e) {
            error.invoke(e.getMessage());
        }
    }

    @ReactMethod
    public void addOrUpdate(ReadableArray geofences, Callback success, Callback error) {
        try {
            List<GeoNotification> geoNotifications = new ArrayList<GeoNotification>();

            for (int i = 0; i < geofences.size(); i++) {
                GeoNotification not = parseFromJSONObject(geofences.getMap(i));
                if (not != null) {
                    geoNotifications.add(not);
                }
            }

            geoNotificationManager.addGeoNotifications(geoNotifications, success);
        } catch(Exception e) {
            error.invoke(e.getMessage());
        }
    }

    @ReactMethod
    public void remove(ReadableArray removeIds, Callback success, Callback error) {
        try {
            List<String> ids = new ArrayList<String>();

            for (int i = 0; i < removeIds.size(); i++) {
                ids.add(removeIds.getString(i));
            }

            geoNotificationManager.removeGeoNotifications(ids, success);
        } catch(Exception e) {
            error.invoke(e.getMessage());
        }
    }

    @ReactMethod
    public void removeAll(Callback success, Callback error) {
        try {
            geoNotificationManager.removeAllGeoNotifications(success);
        } catch(Exception e) {
            error.invoke(e.getMessage());
        }
    }

    @ReactMethod
    public void getWatched(Callback success, Callback error) {
        try {
            List<GeoNotification> geoNotifications = geoNotificationManager.getWatched();
            success.invoke(Gson.get().toJson(geoNotifications));
        } catch(Exception e) {
            error.invoke(e.getMessage());
        }
    }

    private boolean hasPermissions(Context context, String[] permissions) {
        boolean hasAllPermissions = true;

        for (String permission : permissions) {
            //return false instead of assigning, but with this you can log all permission values
            if (!hasPermission(context, permission)) {
                hasAllPermissions = false;
            }
        }

        return hasAllPermissions;
    }

    private boolean hasPermission(Context context, String permission) {
        int res = context.checkCallingOrSelfPermission(permission);

        Log.v(TAG, "permission: " + permission + " = \t\t" +
                (res == PackageManager.PERMISSION_GRANTED ? "GRANTED" : "DENIED"));

        return res == PackageManager.PERMISSION_GRANTED;
    }

    private JSONObject toJSONObject(ReadableMap readableMap) throws JSONException {
        JSONObject jsonObject = new JSONObject();

        ReadableMapKeySetIterator iterator = readableMap.keySetIterator();

        while (iterator.hasNextKey()) {
            String key = iterator.nextKey();
            ReadableType type = readableMap.getType(key);

            switch (type) {
                case Null:
                    jsonObject.put(key, null);
                    break;
                case Boolean:
                    jsonObject.put(key, readableMap.getBoolean(key));
                    break;
                case Number:
                    jsonObject.put(key, readableMap.getDouble(key));
                    break;
                case String:
                    jsonObject.put(key, readableMap.getString(key));
                    break;
                case Map:
                    jsonObject.put(key, toJSONObject(readableMap.getMap(key)));
                    break;
                case Array:
                    jsonObject.put(key, toJSONArray(readableMap.getArray(key)));
                    break;
            }
        }

        return jsonObject;
    }

    private JSONArray toJSONArray(ReadableArray readableArray) throws JSONException {
        JSONArray jsonArray = new JSONArray();

        for (int i = 0; i < readableArray.size(); i++) {
            ReadableType type = readableArray.getType(i);

            switch (type) {
                case Null:
                    jsonArray.put(i, null);
                    break;
                case Boolean:
                    jsonArray.put(i, readableArray.getBoolean(i));
                    break;
                case Number:
                    jsonArray.put(i, readableArray.getDouble(i));
                    break;
                case String:
                    jsonArray.put(i, readableArray.getString(i));
                    break;
                case Map:
                    jsonArray.put(i, toJSONObject(readableArray.getMap(i)));
                    break;
                case Array:
                    jsonArray.put(i, toJSONArray(readableArray.getArray(i)));
                    break;
            }
        }

        return jsonArray;
    }

    private static WritableMap convertJsonToMap(JSONObject jsonObject) throws JSONException {
        WritableMap map = new WritableNativeMap();

        Iterator<String> iterator = jsonObject.keys();
        while (iterator.hasNext()) {
            String key = iterator.next();
            Object value = jsonObject.get(key);
            if (value instanceof JSONObject) {
                map.putMap(key, convertJsonToMap((JSONObject) value));
            } else if (value instanceof  JSONArray) {
                map.putArray(key, convertJsonToArray((JSONArray) value));
            } else if (value instanceof  Boolean) {
                map.putBoolean(key, (Boolean) value);
            } else if (value instanceof  Integer) {
                map.putInt(key, (Integer) value);
            } else if (value instanceof  Double) {
                map.putDouble(key, (Double) value);
            } else if (value instanceof String)  {
                map.putString(key, (String) value);
            } else {
                map.putString(key, value.toString());
            }
        }
        return map;
    }

    private static WritableArray convertJsonToArray(JSONArray jsonArray) throws JSONException {
        WritableArray array = new WritableNativeArray();

        for (int i = 0; i < jsonArray.length(); i++) {
            Object value = jsonArray.get(i);
            if (value instanceof JSONObject) {
                array.pushMap(convertJsonToMap((JSONObject) value));
            } else if (value instanceof  JSONArray) {
                array.pushArray(convertJsonToArray((JSONArray) value));
            } else if (value instanceof  Boolean) {
                array.pushBoolean((Boolean) value);
            } else if (value instanceof  Integer) {
                array.pushInt((Integer) value);
            } else if (value instanceof  Double) {
                array.pushDouble((Double) value);
            } else if (value instanceof String)  {
                array.pushString((String) value);
            } else {
                array.pushString(value.toString());
            }
        }
        return array;
    }

    private static JSONObject convertMapToJson(ReadableMap readableMap) throws JSONException {
        JSONObject object = new JSONObject();
        ReadableMapKeySetIterator iterator = readableMap.keySetIterator();
        while (iterator.hasNextKey()) {
            String key = iterator.nextKey();
            switch (readableMap.getType(key)) {
                case Null:
                    object.put(key, JSONObject.NULL);
                    break;
                case Boolean:
                    object.put(key, readableMap.getBoolean(key));
                    break;
                case Number:
                    object.put(key, readableMap.getDouble(key));
                    break;
                case String:
                    object.put(key, readableMap.getString(key));
                    break;
                case Map:
                    object.put(key, convertMapToJson(readableMap.getMap(key)));
                    break;
                case Array:
                    object.put(key, convertArrayToJson(readableMap.getArray(key)));
                    break;
            }
        }
        return object;
    }

    private static JSONArray convertArrayToJson(ReadableArray readableArray) throws JSONException {
        JSONArray array = new JSONArray();
        for (int i = 0; i < readableArray.size(); i++) {
            switch (readableArray.getType(i)) {
                case Null:
                    break;
                case Boolean:
                    array.put(readableArray.getBoolean(i));
                    break;
                case Number:
                    array.put(readableArray.getDouble(i));
                    break;
                case String:
                    array.put(readableArray.getString(i));
                    break;
                case Map:
                    array.put(convertMapToJson(readableArray.getMap(i)));
                    break;
                case Array:
                    array.put(convertArrayToJson(readableArray.getArray(i)));
                    break;
            }
        }
        return array;
    }

}
