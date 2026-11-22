import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/util/input/binding_input_capture.dart';

/// 滚轮方向曾经被来回搞反多次。根因不是符号算错，而是同一套「dy → up/down」口径
/// 被抄到了多个文件：改一处、漏一处，录制与运行时就各走各的方向。
///
/// 这组测试把口径钉在一处：
///  1. [bindingWheelDirection] 是唯一的 dy→方向词判定，descriptor 必须走它；
///  2. 任何手写的 lib/test 源码里都不许再出现第二份 'up'/'down' 字面量判定。
void main() {
  // bindingWheelInput 会读 HardwareKeyboard.instance 取修饰键。
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bindingWheelDirection 是唯一口径', () {
    for (final invert in [false, true]) {
      test('invert=$invert 时与 bindingWheelInput 的方向词一致', () {
        for (final dy in [-120.0, -40.0, -0.5, 0.0, 0.5, 40.0, 120.0]) {
          expect(
            bindingWheelDirection(dy, invert: invert),
            bindingWheelInput(dy, invert: invert)['direction'],
            reason: 'dy=$dy 时 descriptor 与独立方向词必须一致',
          );
        }
      });
    }

    test('下滚（dy>0，不取反）归一为 down，上滚归一为 up', () {
      expect(bindingWheelDirection(40), 'down');
      expect(bindingWheelDirection(-40), 'up');
    });

    test('取反把方向词翻过来（macOS 按手算）', () {
      expect(bindingWheelDirection(-40, invert: true), 'down');
      expect(bindingWheelDirection(40, invert: true), 'up');
    });
  });

  test('源码里只允许一处 dy → up/down 判定', () {
    // 允许出现字面量的唯一文件：这里的 bindingDirection（鼠标拖动）与
    // bindingWheelDirection（滚轮）共用同一个词表。
    const canonical = 'lib/util/input/binding_input_capture.dart';
    final directionLiteral = RegExp(r"\?\s*'(up|down)'\s*:\s*'(down|up)'");

    final offenders = <String>[];
    for (final dir in [Directory('lib'), Directory('test')]) {
      if (!dir.existsSync()) continue;
      for (final file in dir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final rel = file.path.replaceAll(r'\', '/');
        if (rel.contains('/src/rust/') ||
            rel.endsWith('.g.dart') ||
            rel.endsWith('.freezed.dart') ||
            rel.endsWith('.gr.dart')) {
          continue;
        }
        final lines = file.readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (directionLiteral.hasMatch(lines[i])) {
            offenders.add('$rel:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }

    // canonical 文件本身的两处（bindingDirection + bindingWheelDirection）是源头。
    final outside = offenders.where((line) => !line.startsWith('$canonical:'));
    expect(
      outside,
      isEmpty,
      reason:
          '滚轮方向只能在 bindingWheelDirection 判定，'
          '别在别处再写一份 invert ? -dy : dy < 0 ? "up" : "down"：\n'
          '${outside.join('\n')}',
    );
  });
}
