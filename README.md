# react-native-file-uploader [![npm version](https://badge.fury.io/js/react-native-file-uploader.svg)](https://badge.fury.io/js/react-native-file-uploader)

An iOS and Android cross patform React Native module to upload files from the device local storage to a server using a `multipart/form-data` request. 

# Installation
```
$ npm install react-native-file-uploader --save
$ rnpm link react-native-file-uploader
```

# Usage

```javascript
import FileUploader from 'react-native-file-uploader'

const settings = {
  uri,
  uploadUrl,
  method, // default to 'POST'
  fileName, // default to 'yyyyMMddhhmmss.xxx'
  fieldName, // default to 'file'
  contentType, // default to 'application/octet-stream'
  data: {
    // extra fields to send in the multipart payload
  }
};

FileUploader.upload(settings, (err, res) => {
  // handle result
}, (sent, expectedToSend) => {
  // handle progress
});
      
 ```

### Supported uri types

#### ios
* file:
* absolute path

#### android
* file:
* content:
* absolute path
