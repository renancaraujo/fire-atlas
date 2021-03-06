library flame_fire_atlas;

import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';
import 'package:flame/animation.dart';

import 'package:archive/archive.dart';

import 'dart:convert';
import 'dart:ui';

abstract class Selection {
  String id;
  int x;
  int y;
  int w;
  int h;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {}
      ..['id'] = id
      ..['x'] = x
      ..['y'] = y
      ..['w'] = w
      ..['h'] = h;

    return json;
  }

  fromJson(Map<String, dynamic> json) {
    id = json['id'];
    x = json['x'];
    y = json['y'];
    w = json['w'];
    h = json['h'];
  }
}

class SpriteSelection extends Selection {
  @override
  Map<String, dynamic> toJson() {
    return super.toJson()..['type'] = 'sprite';
  }
}

class AnimationSelection extends Selection {
  int frameCount;
  double stepTime;
  bool loop;

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);

    frameCount = json['frameCount'];
    stepTime = json['stepTime'];
    loop = json['loop'];
  }

  @override
  Map<String, dynamic> toJson() {
    return super.toJson()
      ..['frameCount'] = frameCount
      ..['stepTime'] = stepTime
      ..['loop'] = loop
      ..['type'] = 'animation';
  }
}

class FireAtlas {
  String id;
  int tileSize;
  String imageData;
  Image _image;

  Map<String, Selection> selections = {};

  /// Loads the atlas into memory so it can be used
  ///
  /// [clearImageData] Can be set to false to avoid clearing the stored information about the image on this object, this is true by default, its use is intended to enable serializing this object
  ///
  Future<void> load({bool clearImageData = true}) async {
    _image = await Flame.images.fromBase64(id, imageData);

    // Clear memory
    if (clearImageData) {
      imageData = null;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> selectionsJson = {};
    selections.entries.forEach((entry) {
      selectionsJson[entry.key] = entry.value.toJson();
    });

    final Map<String, dynamic> json = {}
      ..['id'] = id
      ..['tileSize'] = tileSize
      ..['imageData'] = imageData
      ..['selections'] = selectionsJson;

    return json;
  }

  static FireAtlas fromJson(Map<String, dynamic> json) {
    final atlas = FireAtlas()
      ..id = json['id']
      ..tileSize = json['tileSize']
      ..imageData = json['imageData'];

    json['selections'].entries.forEach((entry) {
      Selection selection = entry.value['type'] == 'animation'
          ? AnimationSelection()
          : SpriteSelection();

      selection.fromJson(entry.value);

      atlas.selections[entry.key] = selection;
    });

    return atlas;
  }

  static Future<FireAtlas> fromAsset(String fileName) async {
    final bytes = await Flame.assets.readBinaryFile(fileName);
    final atlas = FireAtlas.deserialize(bytes);
    await atlas.load();
    return atlas;
  }

  List<int> serialize() {
    String raw = jsonEncode(toJson());

    List<int> stringBytes = utf8.encode(raw);
    List<int> gzipBytes = GZipEncoder().encode(stringBytes);
    return gzipBytes;
  }

  static FireAtlas deserialize(List<int> bytes) {
    final unzipedBytes = GZipDecoder().decodeBytes(bytes);
    final unzipedString = utf8.decode(unzipedBytes);
    return fromJson(jsonDecode(unzipedString));
  }

  void _assertImageLoaded() {
    assert(
        _image != null, 'Atlas is not loaded yet, call "load" before using it');
  }

  Sprite getSprite(String selectionId) {
    final selection = selections[selectionId];

    _assertImageLoaded();
    assert(selection != null,
        'There is no selection with the id "$selectionId" on this atlas');
    assert(selection is SpriteSelection,
        'Selection "$selectionId" is not a Sprite');

    return Sprite.fromImage(
      _image,
      x: selection.x.toDouble() * tileSize,
      y: selection.y.toDouble() * tileSize,
      width: (1 + selection.w.toDouble()) * tileSize,
      height: (1 + selection.h.toDouble()) * tileSize,
    );
  }

  Animation getAnimation(String selectionId) {
    final selection = selections[selectionId];

    _assertImageLoaded();
    assert(selection != null,
        'There is no selection with the id "$selectionId" on this atlas');
    assert(selection is AnimationSelection,
        'Selection "$selectionId" is not an Animation');

    final initialX = selection.x.toDouble();

    final animationSelection = selection as AnimationSelection;

    final frameSize =
        (1 + selection.w.toDouble()) / animationSelection.frameCount;

    final width = frameSize * tileSize;
    final height = (1 + selection.h.toDouble()) * tileSize;

    final sprites = List.generate(animationSelection.frameCount, (i) {
      final x = (initialX + i) * frameSize;
      return Sprite.fromImage(
        _image,
        x: x * tileSize,
        y: selection.y.toDouble() * tileSize,
        width: width,
        height: height,
      );
    });

    return Animation.spriteList(
      sprites,
      stepTime: animationSelection.stepTime,
      loop: animationSelection.loop,
    );
  }
}
