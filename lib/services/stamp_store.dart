import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Visa stamps, fetched rather than shipped.
///
/// The art is 216 square images. At the master size that is 419 MB, which is
/// not a bundle and not a download either; re-encoded to 512px WebP the whole
/// set is under 8 MB. Even so it does not ride in the APK — the player only
/// ever needs the continent they are currently travelling through, so the
/// packs come down one continent at a time and stay on the device.
///
/// Everything here degrades to "no stamp yet" rather than failing: a player
/// with no connection still plays, and the map draws the round without its
/// stamp until the pack arrives.
class StampStore {
  StampStore._();
  static final instance = StampStore._();

  static const _manifestAsset = 'assets/campaign/stamp_manifest.json';

  /// Where the packs live in the bucket. Versioned so a re-encode can ship
  /// without fighting whatever is already cached on a device.
  static const _remoteDir = 'stamps';

  /// Named explicitly because Storage was enabled after the app's Firebase
  /// config was generated, so `FirebaseStorage.instance` has no default bucket
  /// to fall back to. Kept here rather than in google-services.json to avoid a
  /// config/secret round-trip.
  static const _bucket = 'gs://atlasarrows-7a720.firebasestorage.app';

  int _version = 0;
  final _packs = <_Pack>[];
  final _packOfRank = <int, _Pack>{};
  Directory? _dir;

  /// Ranks whose image is on disk right now.
  final _onDisk = <int>{};

  /// Bumped whenever a pack lands, so a map already on screen can repaint.
  final revision = ValueNotifier<int>(0);

  bool get isLoaded => _dir != null;

  /// Reads the bundled manifest and takes stock of what is already cached.
  /// Cheap — no network, no downloads.
  Future<void> load() async {
    if (_dir != null) return;
    final raw = jsonDecode(await rootBundle.loadString(_manifestAsset))
        as Map<String, dynamic>;
    _version = (raw['version'] as num).toInt();
    for (final p in (raw['packs'] as List).cast<Map<String, dynamic>>()) {
      final pack = _Pack(
        slug: p['slug'] as String,
        file: p['file'] as String,
        bytes: (p['bytes'] as num).toInt(),
        sha256: p['sha256'] as String,
        ranks: (p['ranks'] as List).cast<num>().map((n) => n.toInt()).toList(),
      );
      _packs.add(pack);
      for (final r in pack.ranks) {
        _packOfRank[r] = pack;
      }
    }

    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/stamps/v$_version');
    await dir.create(recursive: true);
    _dir = dir;
    await _rescan();
  }

  Future<void> _rescan() async {
    _onDisk.clear();
    await for (final f in _dir!.list()) {
      final rank = int.tryParse(f.uri.pathSegments.last.split('.').first);
      if (rank != null) _onDisk.add(rank);
    }
  }

  /// The stamp for a round, or null if it has not been fetched yet.
  File? fileFor(int rank) =>
      _onDisk.contains(rank) ? File('${_dir!.path}/${_pad(rank)}.webp') : null;

  bool hasPackFor(int rank) {
    final pack = _packOfRank[rank];
    return pack != null && pack.ranks.every(_onDisk.contains);
  }

  /// Total bytes still to fetch for the pack covering [rank]. 0 when it is
  /// already here or when no pack covers that round yet.
  int pendingBytesFor(int rank) =>
      hasPackFor(rank) ? 0 : (_packOfRank[rank]?.bytes ?? 0);

  /// Downloads the pack covering [rank] if it is not already on disk.
  ///
  /// Returns true when the stamps for that round are available afterwards.
  /// Never throws: a failure here must not stop a player from reaching a board.
  Future<bool> ensurePackFor(int rank,
      {void Function(double progress)? onProgress}) async {
    final pack = _packOfRank[rank];
    if (pack == null) return false;
    if (hasPackFor(rank)) return true;
    if (pack.inFlight != null) return pack.inFlight!;

    final job = _fetch(pack, onProgress);
    pack.inFlight = job;
    final ok = await job;
    pack.inFlight = null;
    return ok;
  }

  /// Downloads every continent pack not already cached, with one aggregate
  /// [onProgress] (0→1) weighted by pack size. Used at the loading screen so
  /// the stamps are all in place before play — Random mode can jump to any
  /// continent, so one-at-a-time on demand no longer covers it. Never throws;
  /// packs that fail are simply retried the next launch.
  ///
  /// Fetched concurrently rather than one at a time: six small requests to
  /// Storage overlap their connection setup and bandwidth instead of paying
  /// that cost six times over, so wall-clock drops toward the slowest single
  /// pack instead of the sum of all of them.
  Future<void> ensureAllPacks(
      {void Function(double progress)? onProgress}) async {
    final pending =
        _packs.where((p) => !p.ranks.every(_onDisk.contains)).toList();
    final total = pending.fold<int>(0, (a, p) => a + p.bytes);
    if (total == 0) {
      onProgress?.call(1);
      return;
    }
    final doneBytes = <_Pack, int>{for (final p in pending) p: 0};
    void report() {
      final sum = doneBytes.values.fold<int>(0, (a, b) => a + b);
      onProgress?.call(sum / total);
    }

    await Future.wait(pending.map((pack) async {
      final job = pack.inFlight ??
          _fetch(pack, (p) {
            doneBytes[pack] = (p * pack.bytes).round();
            report();
          });
      pack.inFlight = job;
      try {
        await job;
      } finally {
        pack.inFlight = null;
        doneBytes[pack] = pack.bytes;
        report();
      }
    }));
  }

  Future<bool> _fetch(_Pack pack, void Function(double)? onProgress) async {
    final tmp = File('${_dir!.path}/.${pack.file}.part');
    try {
      final ref = FirebaseStorage.instanceFor(bucket: _bucket)
          .ref('$_remoteDir/v$_version/${pack.file}');
      final task = ref.writeToFile(tmp);
      if (onProgress != null) {
        task.snapshotEvents.listen((s) {
          if (s.totalBytes > 0) {
            onProgress(s.bytesTransferred / s.totalBytes);
          }
        }, onError: (_) {/* the await below reports the real outcome */});
      }
      await task;

      final blob = await tmp.readAsBytes();
      // The manifest ships in the APK, so a mismatch means the bucket and the
      // build disagree — install it anyway and you get silently wrong art.
      if (sha256.convert(blob).toString() != pack.sha256) {
        debugPrint('stamps: ${pack.file} checksum mismatch — discarding');
        return false;
      }

      for (final entry in ZipDecoder().decodeBytes(blob)) {
        if (!entry.isFile) continue;
        await File('${_dir!.path}/${entry.name}')
            .writeAsBytes(entry.content as List<int>);
      }
      await _rescan();
      revision.value++;
      onProgress?.call(1);
      return true;
    } catch (e) {
      debugPrint('stamps: ${pack.file} failed — $e');
      return false;
    } finally {
      if (tmp.existsSync()) {
        try {
          await tmp.delete();
        } catch (_) {/* a leftover .part is harmless; it is overwritten */}
      }
    }
  }

  static String _pad(int rank) => rank.toString().padLeft(3, '0');
}

class _Pack {
  _Pack({
    required this.slug,
    required this.file,
    required this.bytes,
    required this.sha256,
    required this.ranks,
  });

  final String slug, file, sha256;
  final int bytes;
  final List<int> ranks;

  /// Two screens can ask for the same continent at once; they share one fetch.
  Future<bool>? inFlight;
}
