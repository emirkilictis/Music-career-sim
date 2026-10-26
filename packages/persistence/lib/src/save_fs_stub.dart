import 'save_fs.dart';

/// No device files on the web: pass a WebSaveFs (docs K218).
SaveFs defaultSaveFs() =>
    throw UnsupportedError('Use SaveSlots.on with a WebSaveFs on the web');
