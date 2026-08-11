import 'dart:math';

final _random = Random();
const _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// A short, collision-resistant id for locally created rows. Not a UUID —
/// these ids never leave the device, so 12 chars of entropy is plenty.
String newId() =>
    List.generate(12, (_) => _alphabet[_random.nextInt(_alphabet.length)])
        .join();
