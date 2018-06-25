'use strict';

/* --- Imports --- */

import {NativeAppEventEmitter, NativeModules} from 'react-native';
const RNGeofencer = NativeModules.Geofencer;


/* --- Member variables --- */

let geofenceListeners = [];


/* --- Class methods --- */

const GeoFencer = {
  /**
   * Transition type constants.
   */
  TransitionType: {
    ENTER: 1,
    EXIT: 2,
    BOTH: 3
  },

  /**
   * Initializing geofencer plugin.
   */
  initialize: function () {
    NativeAppEventEmitter.addListener('GeofencerOnTransitionReceived', this.onTransitionReceived);

    return new Promise((success, failed) => {
      RNGeofencer.initialize(
        (data) => {
          success(data);
        },
        (error) => {
          failed(error);
        }
      );
    });
  },

  /**
   * Remove all native app event listeners.
   */
  destroy: function() {
    NativeAppEventEmitter.removeListener('GeofencerOnTransitionReceived', this.onTransitionReceived);
  },

  /**
   * Adds a listener for receiving geofence events.
   */
  addListener: function(listener) {
    geofenceListeners.push(listener);
  },

  /**
   * Removes a listener.
   */
  removeListener: function(listener) {
    if (geofenceListeners.indexOf(listener) !== -1) {
      geofenceListeners.splice(geofenceListeners.indexOf(listener), 1);
    }
  },

  /**
   * Adding new geofence to monitor.
   * Geofence could override the previously one with the same id.
   */
  addOrUpdate: function (geofences) {
    if (!Array.isArray(geofences)) {
      geofences = [geofences];
    }

    geofences.forEach(coerceProperties);

    return new Promise((success, failed) => {
      RNGeofencer.addOrUpdate(geofences,
        (data) => {
          success(data);
        },
        (error) => {
          failed(error);
        }
      );
    });
  },

  /**
   * Removing geofences with given ids
   */
  remove: function (ids) {
    if (!Array.isArray(ids)) {
      ids = [ids];
    }

    return new Promise((success, failed) => {
      RNGeofencer.remove(ids,
        () => {
          success();
        },
        (error) => {
          failed(error);
        }
      );
    });
  },

  /**
   * Remove all stored geofences on the device
   *
   * @name  removeAll
   *
   * @return {Promise}
   */
  removeAll: function () {
    return new Promise((success, failed) => {
      RNGeofencer.removeAll(
        () => {
          success();
        },
        (error) => {
          failed(error);
        }
      );
    });
  },

  /**
   * Getting all watched geofences from the device
   *
   * @name  getWatched
   * @param  {Function} success callback
   * @param  {Function} error callback
   * @return {Promise} if successful returns geofences array stringify to JSON
   */
  getWatched: function () {
    return new Promise((success, failed) => {
      RNGeofencer.getWatched((watched) => {success(watched)}, (error) => {failed(error)});
    });
  },

  /**
   * Called when app is opened via Notification bar
   *
   * @name onNotificationClicked
   * @param {JSON} notificationData user data from notification
   */
  onNotificationClicked: function (notificationData) {
  },

  /**
   * Called when app received geofence transition event
   * @param  {JSON} geofence
   */
  onTransitionReceived: function (geofence) {
    geofenceListeners.forEach((geofenceListener) => {
      geofenceListener(geofence);
    });
  },
};

function coerceProperties(geofence) {
  if (geofence.id) {
    geofence.id = geofence.id.toString();
  } else {
    throw new Error('Geofence id is not provided');
  }

  if (geofence.latitude) {
    geofence.latitude = coerceNumber('Geofence latitude', geofence.latitude);
  } else {
    throw new Error('Geofence latitude is not provided');
  }

  if (geofence.longitude) {
    geofence.longitude = coerceNumber('Geofence longitude', geofence.longitude);
  } else {
    throw new Error('Geofence longitude is not provided');
  }

  if (geofence.radius) {
    geofence.radius = coerceNumber('Geofence radius', geofence.radius);
  } else {
    throw new Error('Geofence radius is not provided');
  }

  if (geofence.transitionType) {
    geofence.transitionType = coerceNumber('Geofence transitionType', geofence.transitionType);
  } else {
    throw new Error('Geofence transitionType is not provided');
  }

  if (geofence.notification) {
    if (geofence.notification.id) {
      geofence.notification.id = coerceNumber('Geofence notification.id', geofence.notification.id);
    }

    if (geofence.notification.title) {
      geofence.notification.title = geofence.notification.title.toString();
    }

    if (geofence.notification.text) {
      geofence.notification.text = geofence.notification.text.toString();
    }

    if (geofence.notification.smallIcon) {
      geofence.notification.smallIcon = geofence.notification.smallIcon.toString();
    }

    if (geofence.notification.openAppOnClick) {
      geofence.notification.openAppOnClick = coerceBoolean('Geofence notification.openAppOnClick', geofence.notification.openAppOnClick);
    }

    if (geofence.notification.vibration) {
      if (Array.isArray(geofence.notification.vibration)) {
        for (var i = 0; i < geofence.notification.vibration.length; i++) {
          geofence.notification.vibration[i] = coerceInteger('Geofence notification.vibration[' + i + ']', geofence.notification.vibration[i]);
        }
      } else {
        throw new Error('Geofence notification.vibration is not an Array');
      }
    }
  }
}


/* --- Private methods --- */

function coerceNumber(name, value) {
  if (typeof(value) !== 'number') {
    console.warn(name + ' is not a number, trying to convert to number');
    value = Number(value);

    if (isNaN(value)) {
      throw new Error('Cannot convert ' + name + ' to number');
    }
  }

  return value;
}

function coerceInteger(name, value) {
  if (!isInt(value)) {
    console.warn(name + ' is not an integer, trying to convert to integer');
    value = parseInt(value);

    if (isNaN(value)) {
      throw new Error('Cannot convert ' + name + ' to integer');
    }
  }

  return value;
}

function coerceBoolean(name, value) {
  if (typeof(value) !== 'boolean') {
    console.warn(name + ' is not a boolean value, converting to boolean');
    value = Boolean(value);
  }

  return value;
}

function isInt(n) {
  return Number(n) === n && n % 1 === 0;
}


/* --- Exports --- */

module.exports = GeoFencer;