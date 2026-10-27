import 'dart:math' as math;
import 'dart:ui';

/// Parses the SVG path commands used by the brand glyphs.
Path parseSvgPath(String source) {
  final parser = _SvgPathParser(source);
  return parser.parse();
}

class _SvgPathParser {
  _SvgPathParser(this.source);

  final String source;
  var index = 0;
  var command = '';
  var current = Offset.zero;
  var subpathStart = Offset.zero;
  Offset? _lastCubicControl;
  final path = Path();

  static const _commands = 'MmLlHhVvCcSsAaZz';

  Path parse() {
    while (index < source.length) {
      final mark = index;
      _skip();
      if (index >= source.length) break;
      final char = source[index];
      if (_commands.contains(char)) {
        command = char;
        index++;
      } else if (command.isEmpty) {
        throw FormatException(
          'SVG path must start with a command',
          source,
          index,
        );
      }

      if (command != 'C' &&
          command != 'c' &&
          command != 'S' &&
          command != 's') {
        _lastCubicControl = null;
      }

      switch (command) {
        case 'M':
        case 'm':
          _moveTo(command == 'm');
        case 'L':
          _lineTo(false);
        case 'l':
          _lineTo(true);
        case 'H':
          _horizontal(false);
        case 'h':
          _horizontal(true);
        case 'V':
          _vertical(false);
        case 'v':
          _vertical(true);
        case 'C':
          _cubic(false);
        case 'c':
          _cubic(true);
        case 'S':
          _smoothCubic(false);
        case 's':
          _smoothCubic(true);
        case 'A':
          _arc(false);
        case 'a':
          _arc(true);
        case 'Z':
        case 'z':
          path.close();
          current = subpathStart;
          command = '';
        default:
          throw FormatException(
            'Unsupported SVG command $command',
            source,
            index,
          );
      }

      if (index == mark) {
        throw FormatException('SVG path parser stalled', source, index);
      }
    }
    return path;
  }

  void _moveTo(bool relative) {
    final x = _number();
    final y = _number();
    current = relative ? current + Offset(x, y) : Offset(x, y);
    subpathStart = current;
    path.moveTo(current.dx, current.dy);
    command = relative ? 'l' : 'L';
  }

  void _lineTo(bool relative) {
    final x = _number();
    final y = _number();
    current = relative ? current + Offset(x, y) : Offset(x, y);
    path.lineTo(current.dx, current.dy);
  }

  void _horizontal(bool relative) {
    final x = _number();
    current = Offset(relative ? current.dx + x : x, current.dy);
    path.lineTo(current.dx, current.dy);
  }

  void _vertical(bool relative) {
    final y = _number();
    current = Offset(current.dx, relative ? current.dy + y : y);
    path.lineTo(current.dx, current.dy);
  }

  void _cubic(bool relative) {
    final origin = current;
    final x1 = _number();
    final y1 = _number();
    final x2 = _number();
    final y2 = _number();
    final x = _number();
    final y = _number();
    final c1 = relative ? origin + Offset(x1, y1) : Offset(x1, y1);
    final c2 = relative ? origin + Offset(x2, y2) : Offset(x2, y2);
    final end = relative ? origin + Offset(x, y) : Offset(x, y);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
    current = end;
    _lastCubicControl = c2;
  }

  void _smoothCubic(bool relative) {
    final origin = current;
    final x2 = _number();
    final y2 = _number();
    final x = _number();
    final y = _number();
    final c2 = relative ? origin + Offset(x2, y2) : Offset(x2, y2);
    final end = relative ? origin + Offset(x, y) : Offset(x, y);
    final previous = _lastCubicControl;
    final c1 = previous == null
        ? origin
        : Offset(origin.dx * 2 - previous.dx, origin.dy * 2 - previous.dy);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
    current = end;
    _lastCubicControl = c2;
  }

  void _arc(bool relative) {
    final radiusX = _number().abs();
    final radiusY = _number().abs();
    final rotation = _number() * math.pi / 180;
    final largeArc = _flag() == 1;
    final clockwise = _flag() == 1;
    final x = _number();
    final y = _number();
    final end = relative ? current + Offset(x, y) : Offset(x, y);
    if (end != current && radiusX != 0 && radiusY != 0) {
      path.arcToPoint(
        end,
        radius: Radius.elliptical(radiusX, radiusY),
        rotation: rotation,
        largeArc: largeArc,
        clockwise: clockwise,
      );
    } else {
      path.lineTo(end.dx, end.dy);
    }
    current = end;
  }

  void _skip() {
    while (index < source.length) {
      final char = source[index];
      if (char == ' ' ||
          char == ',' ||
          char == '\n' ||
          char == '\r' ||
          char == '\t') {
        index++;
      } else {
        break;
      }
    }
  }

  double _number() {
    _skip();
    final start = index;
    if (index < source.length &&
        (source[index] == '+' || source[index] == '-')) {
      index++;
    }
    var sawDigit = false;
    while (index < source.length && _isDigit(source[index])) {
      sawDigit = true;
      index++;
    }
    if (index < source.length && source[index] == '.') {
      index++;
      while (index < source.length && _isDigit(source[index])) {
        sawDigit = true;
        index++;
      }
    }
    if (!sawDigit) {
      throw FormatException('Expected a number', source, start);
    }
    return double.parse(source.substring(start, index));
  }

  int _flag() {
    _skip();
    if (index >= source.length ||
        (source[index] != '0' && source[index] != '1')) {
      throw FormatException('Expected an arc flag', source, index);
    }
    final flag = source[index] == '1' ? 1 : 0;
    index++;
    return flag;
  }

  bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }
}
