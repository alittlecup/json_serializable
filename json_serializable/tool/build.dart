#!/usr/bin/env dart --checked
// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:build/build.dart';
import 'package:build_config/build_config.dart';
import 'package:build_runner/build_runner.dart';
import 'package:json_serializable/json_serializable.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';

final List<BuilderApplication> builders = [
  applyToRoot(
      new LibraryBuilder(new _NonNullableGenerator(),
          generatedExtension: '.non_nullable.dart', header: _copyrightHeader),
      generateFor: const InputSet(include: const [
        'test/test_files/kitchen_sink.dart',
        'test/test_files/json_test_example.dart'
      ])),
  applyToRoot(
      new LibraryBuilder(new _WrappedGenerator(),
          generatedExtension: '.wrapped.dart', header: _copyrightHeader),
      generateFor: const InputSet(include: const [
        'test/test_files/kitchen_sink.dart',
        'test/test_files/kitchen_sink.non_nullable.dart',
        'test/test_files/json_test_example.dart',
        'test/test_files/json_test_example.non_nullable.dart',
      ])),
  applyToRoot(jsonPartBuilder(header: _copyrightHeader),
      generateFor: const InputSet(
        include: const [
          'test/test_files/json_literal.dart',
          'test/test_files/json_test_example.dart',
          'test/test_files/json_test_example.non_nullable.dart',
          'test/test_files/kitchen_sink.dart',
          'test/test_files/kitchen_sink.non_nullable.dart'
        ],
      )),
  applyToRoot(jsonPartBuilder(useWrappers: true, header: _copyrightHeader),
      generateFor: const InputSet(
        include: const [
          'test/test_files/kitchen_sink*wrapped.dart',
          'test/test_files/json_test_example*wrapped.dart',
        ],
      ))
];

final _copyrightContent =
    '''// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
''';

final _copyrightHeader = '$_copyrightContent\n$defaultFileHeader';

class _NonNullableGenerator extends Generator {
  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) async {
    final path = buildStep.inputId.path;
    final baseName = p.basenameWithoutExtension(path);

    final content = await buildStep.readAsString(buildStep.inputId);
    var replacements = <_Replacement>[
      new _Replacement(_copyrightContent, ''),
      new _Replacement(
        "part '$baseName.g.dart",
        "part '$baseName.non_nullable.g.dart",
      ),
      new _Replacement(
          '@JsonSerializable()', '@JsonSerializable(nullable: false)'),
    ];

    if (baseName == 'kitchen_sink') {
      replacements.addAll([
        new _Replacement('List<T> _defaultList<T>() => null;',
            'List<T> _defaultList<T>() => <T>[];'),
        new _Replacement(
            'Map _defaultMap() => null;', 'Map _defaultMap() => {};'),
        new _Replacement('DateTime dateTime;',
            'DateTime dateTime = new DateTime(1981, 6, 5);')
      ]);
    }

    return _Replacement.generate(content, replacements);
  }
}

class _WrappedGenerator extends Generator {
  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) async {
    final path = buildStep.inputId.path;
    final baseName = p.basenameWithoutExtension(path);

    final content = await buildStep.readAsString(buildStep.inputId);
    var replacements = <_Replacement>[
      new _Replacement(_copyrightContent, ''),
      new _Replacement(
        "part '$baseName.g.dart",
        "part '$baseName.wrapped.g.dart",
      ),
    ];

    return _Replacement.generate(content, replacements);
  }
}

class _Replacement {
  final Pattern existing;
  final String replacement;

  _Replacement(this.existing, this.replacement);

  static String generate(
      String inputContent, Iterable<_Replacement> replacements) {
    var outputContent = inputContent;

    for (var r in replacements) {
      if (!outputContent.contains(r.existing)) {
        throw new StateError(
            'Input string did not contain `${r.existing}` as expected.');
      }
      outputContent = outputContent.replaceAll(r.existing, r.replacement);
    }

    return outputContent;
  }
}

main(List<String> args) {
  run(args, builders);
}
