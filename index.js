import React, { NativeModules, DeviceEventEmitter } from 'react-native'

const callbacks = {};
const progressCallbacks = {};

DeviceEventEmitter.addListener('fileUploadProgress', (e) => {
  const uri = e.uri;
  const callback = progressCallbacks[uri];
  if (callback) {
    callback(e.sent, e.expectedToSend);
  }
});

const FileUploader = {
  upload(settings, callback, progressCallback) {
    const uri = settings.uri;
    callbacks[uri] = callback;
    progressCallbacks[uri] = progressCallback;

    NativeModules.FileUploader.upload(settings, (err, res) => {
      const callback = callbacks[uri];
      if ( callback ) {
        delete callbacks.uri;
      }
      callback(err, res);

      const progressCallback = progressCallbacks[uri];
      if (progressCallback) {
        delete progressCallback.uri;
      }

    });
  }
};

export default FileUploader
