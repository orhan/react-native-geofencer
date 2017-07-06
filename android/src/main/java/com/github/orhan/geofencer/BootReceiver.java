package com.github.orhan.geofencer;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        Logger.setLogger(new Logger(GeofencerModule.TAG, context, false));
        GeoNotificationManager manager = new GeoNotificationManager(context);
        manager.loadFromStorageAndInitializeGeofences();
    }
}