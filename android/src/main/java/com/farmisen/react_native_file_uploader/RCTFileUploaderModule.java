/**
 * Copyright © 2016 Fabrice Armisen <farmisen@gmail.com>
 * This program is free software. It comes without any warranty, to
 * the extent permitted by applicable law. You can redistribute it and/or modify 
 * it under the terms of the Do What The Fuck You Want To Public License, Version 2,
 * as published by Sam Hocevar. See http://www.wtfpl.net/ for more details.
 */

package com.farmisen.react_native_file_uploader;

import android.net.Uri;
import com.facebook.react.bridge.*;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.UUID;

public class RCTFileUploaderModule extends ReactContextBaseJavaModule implements FileUploadProgressListener {

    public static final String URI_FIELD = "uri";
    public static final String METHOD_FIELD = "method";
    public static final String UPLOAD_URL_FIELD = "uploadUrl";
    public static final String CONTENT_TYPE_FIELD = "contentType";
    public static final String FILE_NAME_FIELD = "fileName";
    public static final String FIELD_NAME_FIELD = "fieldName";

    public static final String TWO_HYPHENS = "--";
    public static final String LINE_END = "\r\n";
    public static final int MAX_BUFFER_SIZE = 1024 * 128;

    public RCTFileUploaderModule(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    @Override
    public String getName() {
        return "FileUploader";
    }

    @ReactMethod
    public void upload(final ReadableMap settings, final Callback callback) {
        String uri = settings.getString(URI_FIELD);
        String path = null;
        if (uri.startsWith("file:") || uri.startsWith("content:")) {
            path = (Uri.parse(uri)).getPath();
        }
        else if ( this.isAbsolutePath(uri)) {
            path = uri;
        }
        else {
            callback.invoke("Can't handle " + uri, null);
        }
        this.uploadFile(path, settings, callback);
    }

    private void uploadFile(String path, ReadableMap settings, Callback callback) {
        HttpURLConnection connection = null;
        FileUploadCountingOutputStream outputStream = null;
        InputStream inputStream = null;

        String boundary = "*****" + UUID.randomUUID().toString() + "*****";

        try {
            URL url = new URL(settings.getString(UPLOAD_URL_FIELD));
            connection = (HttpURLConnection) url.openConnection();

            connection.setDoInput(true);
            connection.setDoOutput(true);
            connection.setUseCaches(false);

            String method = getStringParam(settings, METHOD_FIELD, "POST");
            connection.setRequestMethod(method);
            connection.setRequestProperty("Connection", "Keep-Alive");
            connection.setRequestProperty("User-Agent", "React Native File Uploader Android HTTP Client");
            connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=" + boundary);

            String contentType = getStringParam(settings, CONTENT_TYPE_FIELD, "application/octet-stream");
            String fileName = getStringParam(settings, FILE_NAME_FIELD, this.filenameForContentType(contentType));
            String fieldName = getStringParam(settings, FIELD_NAME_FIELD, "file");

            File file = new File(path);
            FileInputStream fileInputStream = new FileInputStream(file);
            int bytesRead, bytesAvailable, bufferSize;
            byte[] buffer;
            int maxBufferSize = MAX_BUFFER_SIZE;

            outputStream = new FileUploadCountingOutputStream(new DataOutputStream(connection.getOutputStream()), file.length(), settings.getString(URI_FIELD), this);
            outputStream.writeBytes(TWO_HYPHENS + boundary + LINE_END);
            outputStream.writeBytes("Content-Disposition: form-data; name=\"" + fieldName + "\"; filename=\"" + fileName + "\"" + LINE_END);
            outputStream.writeBytes("Content-Type: " + contentType + LINE_END);
            outputStream.writeBytes("Content-Transfer-Encoding: binary" + LINE_END);

            outputStream.writeBytes(LINE_END);
            bytesAvailable = fileInputStream.available();
            bufferSize = Math.min(bytesAvailable, maxBufferSize);
            buffer = new byte[bufferSize];
            bytesRead = fileInputStream.read(buffer, 0, bufferSize);
            while (bytesRead > 0) {
                outputStream.write(buffer, 0, bufferSize);
                bytesAvailable = fileInputStream.available();
                bufferSize = Math.min(bytesAvailable, maxBufferSize);
                bytesRead = fileInputStream.read(buffer, 0, bufferSize);
            }
            outputStream.writeBytes(LINE_END);

            ReadableMap params = getMapParam(settings, "data", Arguments.createMap());
            ReadableMapKeySetIterator keys = params.keySetIterator();
            while (keys.hasNextKey()) {
                String key = keys.nextKey();
                ReadableType type = params.getType(key);
                String value = null;
                switch (type) {
                    case String:
                        value = params.getString(key);
                        break;
                    case Number:
                        value = Integer.toString(params.getInt(key));
                        break;
                    default:
                        callback.invoke(type.toString() + " type not supported.", null);
                        break;
                }

                outputStream.writeBytes(TWO_HYPHENS + boundary + LINE_END);
                outputStream.writeBytes("Content-Disposition: form-data; name=\"" + key + "\"" + LINE_END);
                outputStream.writeBytes("Content-Type: text/plain" + LINE_END);
                outputStream.writeBytes(LINE_END + value + LINE_END);
            }

            outputStream.writeBytes(TWO_HYPHENS + boundary + TWO_HYPHENS + LINE_END);

            inputStream = connection.getInputStream();
            String responseBody = this.streamToString(inputStream);

            fileInputStream.close();
            inputStream.close();
            outputStream.flush();
            outputStream.close();

            WritableMap result = Arguments.createMap();
            result.putString("data", responseBody);
            result.putInt("status", connection.getResponseCode());
            callback.invoke(null, result);
        } catch (Exception e) {
            callback.invoke(e.getLocalizedMessage(), null);
        }
    }

    private ReadableMap getMapParam(ReadableMap map, String key, ReadableMap defaultValue) {
        if ( map.hasKey(key)) {
            return map.getMap(key);
        } else {
            return defaultValue;
        }
    }

    private String getStringParam(ReadableMap map, String key, String defaultValue) {
        if ( map.hasKey(key)) {
            return map.getString(key);
        } else {
            return defaultValue;
        }
    }

    private String filenameForContentType(String contentType) {
        String[] components = contentType.split("/");
        String extension = components.length == 2
                ? components[1]
                : "";
        return new SimpleDateFormat("yyyyMMddhhmmss").format(new Date()) + extension;
    }

    private boolean isAbsolutePath(String path) {
        return (new File(path)).exists();
    }

    private String streamToString(InputStream is) {
        BufferedReader reader = new BufferedReader(new InputStreamReader(is));
        StringBuilder sb = new StringBuilder();

        String line = null;
        try {
            while ((line = reader.readLine()) != null) {
                sb.append(line);
            }
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            try {
                is.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        return sb.toString();
    }

    @Override
    public void transferred(String fileRef, long transferred, long total) {
        WritableMap params = Arguments.createMap();
        params.putString("uri", fileRef);
        params.putString("sent", Long.toString(transferred));
        params.putString("expectedToSend", Long.toString(total));
        this.getReactApplicationContext()
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit("fileUploadProgress", params);
    }
}
