/**
 * Copyright © 2016 Fabrice Armisen <farmisen@gmail.com>
 * This program is free software. It comes without any warranty, to
 * the extent permitted by applicable law. You can redistribute it and/or modify 
 * it under the terms of the Do What The Fuck You Want To Public License, Version 2,
 * as published by Sam Hocevar. See http://www.wtfpl.net/ for more details.
 *
 * Inspired by http://stackoverflow.com/questions/16797468/how-to-send-a-multipart-form-data-post-in-android-with-volley
 */


package com.farmisen.react_native_file_uploader;

public interface FileUploadProgressListener {
    void transferred(String fileRef, long transferred, long total);
}
