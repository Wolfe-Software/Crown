import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as image;

const _sourceWidth = 1024;
const _sourceHeight = 1536;
const _iconSize = 1024;
const _cropX = 192;
const _cropY = 448;
const _cropSize = 640;
const _maskScale = 4;
const _brokenLogoSaturation = .12;
const _fractureGap = 10.0;
const _fracturePath = <(double, double)>[
  (495, 90),
  (506, 175),
  (500, 215),
  (515, 245),
  (510, 300),
  (530, 340),
  (522, 430),
  (550, 535),
  (545, 625),
  (580, 745),
  (572, 770),
  (606, 810),
  (615, 870),
];

Future<void> generateAppIcon({
  required String sourcePath,
  required String outputPath,
}) async {
  final artwork = await _createSquareArtwork(sourcePath);
  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsBytes(image.encodePng(artwork));
}

Future<void> generateMarbleBackground({
  required String sourcePath,
  required String outputPath,
}) async {
  final source = image.decodePng(await File(sourcePath).readAsBytes());
  if (source == null) {
    throw StateError('Unable to decode $sourcePath as a PNG image.');
  }
  if (source.width != _sourceWidth || source.height != _sourceHeight) {
    throw StateError(
      'Expected a ${_sourceWidth}x$_sourceHeight source image, '
      'but found ${source.width}x${source.height}.',
    );
  }

  var sampledRed = 0.0;
  var sampledGreen = 0.0;
  var sampledBlue = 0.0;
  var sampleCount = 0;
  for (var y = 420; y < 500; y += 4) {
    for (var x = 240; x < 784; x += 4) {
      final pixel = source.getPixel(x, y);
      sampledRed += pixel.r;
      sampledGreen += pixel.g;
      sampledBlue += pixel.b;
      sampleCount++;
    }
  }

  final baseRed = sampledRed / sampleCount;
  final baseGreen = sampledGreen / sampleCount;
  final baseBlue = sampledBlue / sampleCount;

  double noise(double x, double y) {
    double hash(int gridX, int gridY) {
      final value = math.sin(gridX * 127.1 + gridY * 311.7) * 43758.5453;
      return value - value.floor();
    }

    final x0 = x.floor();
    final y0 = y.floor();
    final blendX = (x - x0) * (x - x0) * (3 - 2 * (x - x0));
    final blendY = (y - y0) * (y - y0) * (3 - 2 * (y - y0));
    final top = hash(x0, y0) * (1 - blendX) + hash(x0 + 1, y0) * blendX;
    final bottom =
        hash(x0, y0 + 1) * (1 - blendX) + hash(x0 + 1, y0 + 1) * blendX;
    return top * (1 - blendY) + bottom * blendY;
  }

  double turbulence(double x, double y) {
    var value = 0.0;
    var amplitude = .5;
    var frequency = 1.0;
    for (var octave = 0; octave < 5; octave++) {
      value += noise(x * frequency, y * frequency) * amplitude;
      frequency *= 2;
      amplitude *= .5;
    }
    return value;
  }

  final marble = image.Image(
    width: _iconSize,
    height: _iconSize,
    numChannels: 3,
  );
  for (final pixel in marble) {
    final x = pixel.x.toDouble();
    final y = pixel.y.toDouble();
    final broadNoise = turbulence(x / 310, y / 310);
    final fineNoise = turbulence(x / 125 + 11, y / 125 + 7);
    final warp = (broadNoise - .48) * 2.2 + (fineNoise - .48) * .35;
    final cloud = (broadNoise - .48) * 1.15 + (fineNoise - .48) * .35;
    final primaryField = math.sin(
      x * .0035 + y * .0054 + warp + math.sin(y * .0026) * .5,
    );
    final secondaryField = math.sin(
      x * .0045 - y * .0028 + warp * .6 + math.sin(x * .0031) * .42,
    );
    final primaryVein = math.pow(
      math.max(0, 1 - primaryField.abs() / .115),
      2.4,
    );
    final secondaryVein = math.pow(
      math.max(0, 1 - secondaryField.abs() / .085),
      2.8,
    );
    final pearl = math.max(0, fineNoise - .68) * 2.2;

    pixel
      ..r =
          (baseRed +
                  cloud * 16 +
                  pearl * 8 -
                  primaryVein * 27 -
                  secondaryVein * 13)
              .clamp(0, 255)
      ..g =
          (baseGreen +
                  cloud * 14 +
                  pearl * 8 -
                  primaryVein * 35 -
                  secondaryVein * 17)
              .clamp(0, 255)
      ..b =
          (baseBlue +
                  cloud * 12 +
                  pearl * 7 -
                  primaryVein * 43 -
                  secondaryVein * 21)
              .clamp(0, 255);
  }

  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsBytes(image.encodePng(marble));
}

Future<void> generateCrownLogo({
  required String sourcePath,
  required String outputPath,
}) async {
  final artwork = await _createSquareArtwork(sourcePath);
  final mask = _createCrownMask();
  final logo = image.Image(width: _iconSize, height: _iconSize, numChannels: 4);

  for (final pixel in logo) {
    final sourcePixel = artwork.getPixel(pixel.x, pixel.y);
    final alpha = mask.getPixel(pixel.x, pixel.y).r.toInt();
    pixel
      ..r = sourcePixel.r
      ..g = sourcePixel.g
      ..b = sourcePixel.b
      ..a = alpha;
  }

  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsBytes(image.encodePng(logo));
}

Future<void> generateBrokenCrownLogo({
  required String sourcePath,
  required String outputPath,
}) async {
  final source = image.decodePng(await File(sourcePath).readAsBytes());
  if (source == null) {
    throw StateError('Unable to decode $sourcePath as a PNG image.');
  }
  if (source.width != _iconSize || source.height != _iconSize) {
    throw StateError(
      'Expected a ${_iconSize}x$_iconSize crown logo, '
      'but found ${source.width}x${source.height}.',
    );
  }

  final broken = image.Image(
    width: _iconSize,
    height: _iconSize,
    numChannels: 4,
  );
  _drawBrokenHalf(
    source: source,
    destination: broken,
    isLeft: true,
    angleDegrees: -3,
    horizontalShift: -30,
  );
  _drawBrokenHalf(
    source: source,
    destination: broken,
    isLeft: false,
    angleDegrees: 3,
    horizontalShift: 30,
  );

  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsBytes(image.encodePng(broken));
}

Future<void> generateDrawLogo({
  required String sourcePath,
  required String outputPath,
}) async {
  final source = image.decodePng(await File(sourcePath).readAsBytes());
  if (source == null) {
    throw StateError('Unable to decode $sourcePath as a PNG image.');
  }
  if (source.width != _iconSize || source.height != _iconSize) {
    throw StateError(
      'Expected a ${_iconSize}x$_iconSize crown logo, '
      'but found ${source.width}x${source.height}.',
    );
  }

  final mask = _createDrawMask();
  final draw = image.Image(width: _iconSize, height: _iconSize, numChannels: 4);
  for (final pixel in draw) {
    final alpha = mask.getPixel(pixel.x, pixel.y).r.toInt();
    if (alpha == 0) continue;

    final directionalHighlight = math.exp(
      -math.pow((pixel.x - 430 - pixel.y * .035) / 82, 2),
    );
    final reflectedHighlight = math.exp(-math.pow((pixel.x - 705) / 145, 2));
    final brushedTexture =
        math.sin(pixel.y * .31 + math.sin(pixel.x * .025) * 2.4) * .035 +
        math.sin(pixel.x * .075) * .025;
    final nearEdge =
        mask.getPixel((pixel.x - 8).clamp(0, _iconSize - 1), pixel.y).r < 128 ||
        mask.getPixel((pixel.x + 8).clamp(0, _iconSize - 1), pixel.y).r < 128 ||
        mask.getPixel(pixel.x, (pixel.y - 8).clamp(0, _iconSize - 1)).r < 128 ||
        mask.getPixel(pixel.x, (pixel.y + 8).clamp(0, _iconSize - 1)).r < 128;
    final shade =
        .58 +
        directionalHighlight * .52 +
        reflectedHighlight * .16 +
        brushedTexture -
        (nearEdge ? .3 : 0);
    pixel
      ..r = (238 * shade).clamp(38, 255)
      ..g = (158 * shade).clamp(20, 240)
      ..b = (35 * shade).clamp(6, 105)
      ..a = alpha;
  }

  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsBytes(image.encodePng(draw));
}

image.Image _createDrawMask() {
  final mask = image.Image(
    width: _iconSize * _maskScale,
    height: _iconSize * _maskScale,
    numChannels: 1,
  );
  final white = image.ColorUint8(1)..r = 255;

  // A tiered finial and tapered standard keep the silhouette crown-like.
  image.fillCircle(
    mask,
    x: 512 * _maskScale,
    y: 145 * _maskScale,
    radius: 58 * _maskScale,
    color: white,
  );
  image.fillRect(
    mask,
    x1: 482 * _maskScale,
    y1: 185 * _maskScale,
    x2: 542 * _maskScale,
    y2: 230 * _maskScale,
    radius: 18 * _maskScale,
    color: white,
    alphaBlend: false,
  );
  _fillPolygon(mask, [(487, 210), (537, 210), (550, 690), (474, 690)], white);
  for (final (y, width, height) in [
    (245, 92, 24),
    (668, 118, 30),
    (704, 164, 34),
  ]) {
    image.fillRect(
      mask,
      x1: (512 - width / 2).round() * _maskScale,
      y1: y * _maskScale,
      x2: (512 + width / 2).round() * _maskScale,
      y2: (y + height) * _maskScale,
      radius: (height / 2).round() * _maskScale,
      color: white,
      alphaBlend: false,
    );
  }

  // The beam carries rounded ornamental caps and a heavier central collar.
  image.fillRect(
    mask,
    x1: 185 * _maskScale,
    y1: 326 * _maskScale,
    x2: 839 * _maskScale,
    y2: 376 * _maskScale,
    radius: 25 * _maskScale,
    color: white,
    alphaBlend: false,
  );
  for (final x in [185, 839]) {
    image.fillCircle(
      mask,
      x: x * _maskScale,
      y: 351 * _maskScale,
      radius: 29 * _maskScale,
      color: white,
    );
  }
  image.fillCircle(
    mask,
    x: 512 * _maskScale,
    y: 351 * _maskScale,
    radius: 48 * _maskScale,
    color: white,
  );

  // Paired suspension lines remain legible while giving the scales finesse.
  for (final (x1, y1, x2, y2) in [
    (252, 370, 188, 548),
    (270, 370, 210, 548),
    (348, 370, 374, 548),
    (366, 370, 396, 548),
    (658, 370, 628, 548),
    (676, 370, 650, 548),
    (754, 370, 814, 548),
    (772, 370, 836, 548),
  ]) {
    image.drawLine(
      mask,
      x1: x1 * _maskScale,
      y1: y1 * _maskScale,
      x2: x2 * _maskScale,
      y2: y2 * _maskScale,
      thickness: 10 * _maskScale,
      color: white,
    );
  }

  final leftPan = <(double, double)>[(142, 548), (404, 548)];
  _appendCubic(leftPan, (394, 630), (338, 682), (273, 682));
  _appendCubic(leftPan, (208, 682), (152, 630), (142, 548));
  _fillPolygon(mask, leftPan, white);
  final rightPan = <(double, double)>[(620, 548), (882, 548)];
  _appendCubic(rightPan, (872, 630), (816, 682), (751, 682));
  _appendCubic(rightPan, (686, 682), (630, 630), (620, 548));
  _fillPolygon(mask, rightPan, white);
  for (final (x1, x2) in [(136, 410), (614, 888)]) {
    image.fillRect(
      mask,
      x1: x1 * _maskScale,
      y1: 538 * _maskScale,
      x2: x2 * _maskScale,
      y2: 568 * _maskScale,
      radius: 15 * _maskScale,
      color: white,
      alphaBlend: false,
    );
  }

  // Three stepped plinths visually anchor the standard.
  for (final (y, width, height) in [
    (744, 236, 42),
    (782, 310, 48),
    (820, 382, 56),
  ]) {
    image.fillRect(
      mask,
      x1: (512 - width / 2).round() * _maskScale,
      y1: y * _maskScale,
      x2: (512 + width / 2).round() * _maskScale,
      y2: (y + height) * _maskScale,
      radius: (height / 2).round() * _maskScale,
      color: white,
      alphaBlend: false,
    );
  }
  return image.copyResize(
    mask,
    width: _iconSize,
    height: _iconSize,
    interpolation: image.Interpolation.average,
  );
}

void _drawBrokenHalf({
  required image.Image source,
  required image.Image destination,
  required bool isLeft,
  required double angleDegrees,
  required double horizontalShift,
}) {
  final pivotX = isLeft ? 384.0 : 640.0;
  const pivotY = 500.0;
  final inverseAngle = -angleDegrees * math.pi / 180;
  final cosine = math.cos(inverseAngle);
  final sine = math.sin(inverseAngle);

  for (final outputPixel in destination) {
    final translatedX = outputPixel.x - horizontalShift - pivotX;
    final translatedY = outputPixel.y - pivotY;
    final sourceX = pivotX + translatedX * cosine - translatedY * sine;
    final sourceY = pivotY + translatedX * sine + translatedY * cosine;
    if (sourceX < 0 ||
        sourceX >= source.width - 1 ||
        sourceY < 0 ||
        sourceY >= source.height - 1) {
      continue;
    }

    final seam = _fractureX(sourceY);
    final boundary = seam + (isLeft ? -_fractureGap / 2 : _fractureGap / 2);
    final distance = isLeft ? boundary - sourceX : sourceX - boundary;
    final coverage = (distance + .5).clamp(0.0, 1.0);
    if (coverage == 0) continue;

    final sourcePixel = source.getPixelInterpolate(
      sourceX,
      sourceY,
      interpolation: image.Interpolation.cubic,
    );
    final alpha = sourcePixel.aNormalized * coverage;
    if (alpha <= outputPixel.aNormalized) continue;

    final luminance =
        sourcePixel.r * .2126 + sourcePixel.g * .7152 + sourcePixel.b * .0722;
    final fractureShade = distance < 5 ? .65 + distance * .07 : 1.0;
    outputPixel
      ..r =
          (luminance + (sourcePixel.r - luminance) * _brokenLogoSaturation) *
          fractureShade
      ..g =
          (luminance + (sourcePixel.g - luminance) * _brokenLogoSaturation) *
          fractureShade
      ..b =
          (luminance + (sourcePixel.b - luminance) * _brokenLogoSaturation) *
          fractureShade
      ..a = alpha * 255;
  }
}

double _fractureX(double y) {
  if (y <= _fracturePath.first.$2) return _fracturePath.first.$1;
  for (var index = 1; index < _fracturePath.length; index++) {
    final start = _fracturePath[index - 1];
    final end = _fracturePath[index];
    if (y <= end.$2) {
      final progress = (y - start.$2) / (end.$2 - start.$2);
      return start.$1 + (end.$1 - start.$1) * progress;
    }
  }
  return _fracturePath.last.$1;
}

Future<image.Image> _createSquareArtwork(String sourcePath) async {
  final source = image.decodePng(await File(sourcePath).readAsBytes());
  if (source == null) {
    throw StateError('Unable to decode $sourcePath as a PNG image.');
  }
  if (source.width != _sourceWidth || source.height != _sourceHeight) {
    throw StateError(
      'Expected a ${_sourceWidth}x$_sourceHeight source image, '
      'but found ${source.width}x${source.height}.',
    );
  }

  final cropped = image.copyCrop(
    source,
    x: _cropX,
    y: _cropY,
    width: _cropSize,
    height: _cropSize,
  );
  final resized = image.copyResize(
    cropped,
    width: _iconSize,
    height: _iconSize,
    interpolation: image.Interpolation.cubic,
  );
  final opaque = image.Image(
    width: _iconSize,
    height: _iconSize,
    numChannels: 3,
  );
  image.fill(opaque, color: image.ColorRgb8(218, 199, 167));
  image.compositeImage(opaque, resized);
  return opaque;
}

image.Image _createCrownMask() {
  final mask = image.Image(
    width: _iconSize * _maskScale,
    height: _iconSize * _maskScale,
    numChannels: 1,
  );
  final white = image.ColorUint8(1)..r = 255;

  for (final (x, y, radius) in [
    (512, 164, 54),
    (173, 367, 53),
    (855, 367, 53),
  ]) {
    image.fillCircle(
      mask,
      x: x * _maskScale,
      y: y * _maskScale,
      radius: radius * _maskScale,
      color: white,
    );
  }

  final body = <(double, double)>[(176, 398)];
  _appendCubic(body, (220, 435), (280, 509), (334, 514));
  _appendCubic(body, (406, 526), (472, 342), (494, 213));
  body.add((530, 213));
  _appendCubic(body, (552, 342), (618, 526), (690, 514));
  _appendCubic(body, (744, 509), (804, 435), (848, 398));
  body.add((775, 738));
  _appendCubic(body, (648, 721), (376, 721), (249, 738));
  _fillPolygon(mask, body, white);

  image.fillRect(
    mask,
    x1: 243 * _maskScale,
    y1: 770 * _maskScale,
    x2: 778 * _maskScale,
    y2: 852 * _maskScale,
    radius: 41 * _maskScale,
    color: white,
    alphaBlend: false,
  );

  return image.copyResize(
    mask,
    width: _iconSize,
    height: _iconSize,
    interpolation: image.Interpolation.average,
  );
}

void _appendCubic(
  List<(double, double)> points,
  (double, double) control1,
  (double, double) control2,
  (double, double) end,
) {
  final start = points.last;
  for (var step = 1; step <= 24; step++) {
    final t = step / 24;
    final inverse = 1 - t;
    points.add((
      inverse * inverse * inverse * start.$1 +
          3 * inverse * inverse * t * control1.$1 +
          3 * inverse * t * t * control2.$1 +
          t * t * t * end.$1,
      inverse * inverse * inverse * start.$2 +
          3 * inverse * inverse * t * control1.$2 +
          3 * inverse * t * t * control2.$2 +
          t * t * t * end.$2,
    ));
  }
}

void _fillPolygon(
  image.Image mask,
  List<(double, double)> points,
  image.Color color,
) {
  final minimumY = points.map((point) => point.$2).reduce(math.min);
  final maximumY = points.map((point) => point.$2).reduce(math.max);
  final startY = (minimumY * _maskScale).floor();
  final endY = (maximumY * _maskScale).ceil();

  for (var scaledY = startY; scaledY <= endY; scaledY++) {
    final y = (scaledY + 0.5) / _maskScale;
    final intersections = <double>[];
    for (var index = 0; index < points.length; index++) {
      final start = points[index];
      final end = points[(index + 1) % points.length];
      if (start.$2 <= y && end.$2 > y || end.$2 <= y && start.$2 > y) {
        final position = (y - start.$2) / (end.$2 - start.$2);
        intersections.add(start.$1 + position * (end.$1 - start.$1));
      }
    }
    intersections.sort();
    for (var index = 0; index + 1 < intersections.length; index += 2) {
      final startX = (intersections[index] * _maskScale).ceil();
      final endX = (intersections[index + 1] * _maskScale).floor();
      final row = mask.getRange(startX, scaledY, endX - startX + 1, 1);
      while (row.moveNext()) {
        row.current.set(color);
      }
    }
  }
}

Future<void> main() async {
  const sourcePath = 'assets/AppIcon.png';
  const iconOutputPath = 'assets/generated/AppIconSquare.png';
  const marbleOutputPath = 'assets/MarbleBackground.png';
  const logoOutputPath = 'assets/CrownLogo.png';
  const brokenLogoOutputPath = 'assets/BrokenCrownLogo.png';
  const drawLogoOutputPath = 'assets/DrawLogo.png';
  await generateAppIcon(sourcePath: sourcePath, outputPath: iconOutputPath);
  await generateMarbleBackground(
    sourcePath: sourcePath,
    outputPath: marbleOutputPath,
  );
  await generateCrownLogo(sourcePath: sourcePath, outputPath: logoOutputPath);
  await generateBrokenCrownLogo(
    sourcePath: logoOutputPath,
    outputPath: brokenLogoOutputPath,
  );
  await generateDrawLogo(
    sourcePath: logoOutputPath,
    outputPath: drawLogoOutputPath,
  );
  stdout.writeln(
    'Generated $iconOutputPath, $marbleOutputPath, $logoOutputPath, '
    '$brokenLogoOutputPath, and $drawLogoOutputPath from $sourcePath.',
  );
}
