import 'dart:convert';

import 'package:flutter/material.dart';

ImageProvider<Object>? avatarImageProvider(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final dataMatch = RegExp(
    r'^data:image/[^;]+;base64,(.+)$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (dataMatch != null) {
    final encoded = dataMatch.group(1);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(encoded));
    } on FormatException {
      return null;
    }
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return null;
  return NetworkImage(trimmed);
}
