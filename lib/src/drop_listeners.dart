import "dart:html";
import "dart:async";
import "package:imagebox/src/exif.dart";
import "package:imagebox/src/dropper.dart";

abstract class ImageDropListener implements FileDropListener {
  bool isMimeTypeAccepted(String mimeType) => mimeType.startsWith("image/");
}

class ImageDropBlobSource extends ImageDropListener {
  ImageDropBlobSource(Element dropTarget):
    this.dropTarget = dropTarget ?? document.body {
    _dropper = new Dropper(this, dropTarget);
  }

  void detach() => _dropper.detach();
  void reattach() => _dropper.reattach();

  void set accepting(bool value) {
    if (value)
			dropTarget.classes.add("dragOver");
		else
			dropTarget.classes.remove("dragOver");
  }

  void acceptBlobs(List<Blob> files) {
    _onBlob.addStream(new Stream.fromIterable(files));
  }

  StreamController<Blob> _onBlob = new StreamController();
  Stream<Blob> get onBlob => _onBlob.stream;

  Future<Null> readExif(Blob blob) async {
    ExifInfo info = await ExifInfo.fromBlob(blob);
    print("Orientation: ${info.orientation}");
    print("${info}");
  }

  final Element dropTarget;
  Dropper _dropper;
}
