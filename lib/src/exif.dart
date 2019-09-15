import "dart:async";
import "package:exifdart/exifdart_html.dart" as exif;
import "dart:html";

class ExifInfo {
  static Future<ExifInfo> fromBlob(Blob blob) async {
    if (blob.type == "image/jpeg") {
      Map<String, dynamic> tags = await exif.readExifFromBlob(blob);
      if (tags["Orientation"] is! num)
        tags.remove("Orientation");
      return new ExifInfo._(tags);
    } else {
      return new ExifInfo._({});
    }
  }

  ExifInfo._(this.tags);

  int get orientation => tags["Orientation"];

  String toString() => tags.keys.map((String key) => "${key}: ${tags[key]}").join("\n");

  Map<String, dynamic> tags;
}
