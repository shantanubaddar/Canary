part of '../../main.dart';

Future<List<String>> pickAudioPathsWithFallback(BuildContext context) async {
  return showManualPathImportDialog(context);
}

Future<List<String>> showManualPathImportDialog(BuildContext context) async {
  final controller = TextEditingController();
  var selectedPaths = <String>[];
  final paths = await showDialog<List<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: CanaryTheme.background,
        title: const Text('Import Audio'),
        content: SizedBox(
          width: 640,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste an audio file path or folder path. You can also try Browse, but pasted paths work even when the desktop file picker is unavailable.',
                style: TextStyle(color: CanaryTheme.muted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'File or folder path',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final browsed = await showCanaryFileBrowser(context);
                      setState(() => selectedPaths = browsed);
                    },
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Browse'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (selectedPaths.isNotEmpty)
                Text(
                  '${selectedPaths.length} file(s) selected from Browse.',
                  style: const TextStyle(color: CanaryTheme.muted),
                )
              else
                const Text(
                  'Tip: paste /home/shantanu/Music or a direct .mp3/.flac path.',
                  style: TextStyle(color: CanaryTheme.faint, fontSize: 12),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, const <String>[]),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final manual = audioPathsFromManualInput(controller.text);
              Navigator.pop(
                context,
                manual.isNotEmpty ? manual : selectedPaths,
              );
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
  return paths ?? const [];
}

Future<List<String>> tryBrowseAudioFiles() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'mp3',
        'flac',
        'aac',
        'm4a',
        'ogg',
        'wav',
        'opus',
      ],
    );
    return result?.paths.whereType<String>().toList() ?? const <String>[];
  } catch (_) {
    return const [];
  }
}

Future<List<String>> showCanaryFileBrowser(BuildContext context) async {
  var currentDirectory = Directory(
    Platform.environment['HOME'] ?? '/home/shantanu',
  );
  var selected = <String>{};

  List<FileSystemEntity> entriesFor(Directory directory) {
    try {
      final entries = directory.listSync(followLinks: false).where((entry) {
        if (entry is Directory) return true;
        if (entry is File) return isAudioPath(entry.path);
        return false;
      }).toList();
      entries.sort((a, b) {
        final aDir = a is Directory;
        final bDir = b is Directory;
        if (aDir != bDir) return aDir ? -1 : 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });
      return entries;
    } catch (_) {
      return const [];
    }
  }

  final result = await showDialog<List<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final entries = entriesFor(currentDirectory);
        return AlertDialog(
          backgroundColor: CanaryTheme.background,
          title: const Text('Browse Music'),
          content: SizedBox(
            width: 820,
            height: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Up',
                      onPressed:
                          currentDirectory.parent.path == currentDirectory.path
                          ? null
                          : () => setState(
                              () => currentDirectory = currentDirectory.parent,
                            ),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    Expanded(
                      child: Text(
                        currentDirectory.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CanaryTheme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(
                        () => selected = audioPathsFromManualInput(
                          currentDirectory.path,
                        ).toSet(),
                      ),
                      icon: const Icon(Icons.library_music_rounded),
                      label: const Text('Select Folder'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .62),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: CanaryTheme.border),
                    ),
                    child: entries.isEmpty
                        ? const Center(
                            child: Text(
                              'No folders or audio files here.',
                              style: TextStyle(color: CanaryTheme.muted),
                            ),
                          )
                        : ListView.builder(
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              final directory = entry is Directory
                                  ? entry
                                  : null;
                              final isDirectory = directory != null;
                              final name = entry.path
                                  .split(Platform.pathSeparator)
                                  .last;
                              final checked = selected.contains(entry.path);
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  isDirectory
                                      ? Icons.folder_rounded
                                      : Icons.audio_file_rounded,
                                  color: isDirectory
                                      ? CanaryTheme.amber
                                      : CanaryTheme.leaf,
                                ),
                                title: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: isDirectory
                                    ? const Text(
                                        'Folder',
                                        style: TextStyle(
                                          color: CanaryTheme.muted,
                                        ),
                                      )
                                    : Text(
                                        entry.path,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: CanaryTheme.muted,
                                        ),
                                      ),
                                trailing: isDirectory
                                    ? const Icon(Icons.chevron_right_rounded)
                                    : Checkbox(
                                        value: checked,
                                        onChanged: (value) => setState(() {
                                          if (value ?? false) {
                                            selected.add(entry.path);
                                          } else {
                                            selected.remove(entry.path);
                                          }
                                        }),
                                      ),
                                onTap: () {
                                  if (isDirectory) {
                                    setState(
                                      () => currentDirectory = directory,
                                    );
                                  } else {
                                    setState(() {
                                      if (checked) {
                                        selected.remove(entry.path);
                                      } else {
                                        selected.add(entry.path);
                                      }
                                    });
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${selected.length} audio file(s) selected',
                  style: const TextStyle(color: CanaryTheme.muted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, const <String>[]),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, selected.toList()..sort()),
              child: const Text('Use Selected'),
            ),
          ],
        );
      },
    ),
  );
  return result ?? const [];
}

List<String> audioPathsFromManualInput(String rawPath) {
  final path = rawPath.trim().replaceFirst(
    RegExp(r'^~'),
    Platform.environment['HOME'] ?? '~',
  );
  if (path.isEmpty) {
    return const [];
  }
  final file = File(path);
  if (file.existsSync() && isAudioPath(file.path)) {
    return [file.path];
  }
  final directory = Directory(path);
  if (!directory.existsSync()) {
    return const [];
  }
  return directory
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .map((file) => file.path)
      .where(isAudioPath)
      .toList()
    ..sort();
}

bool isAudioPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.mp3') ||
      lower.endsWith('.flac') ||
      lower.endsWith('.aac') ||
      lower.endsWith('.m4a') ||
      lower.endsWith('.ogg') ||
      lower.endsWith('.wav') ||
      lower.endsWith('.opus');
}

Future<void> showImportFilesDialog(
  BuildContext context,
  LibraryController library,
) async {
  final paths = await pickAudioPathsWithFallback(context);
  if (paths.isEmpty || !context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (context) =>
        ImportConfirmationDialog(library: library, paths: paths),
  );
}

class ImportConfirmationDialog extends StatefulWidget {
  const ImportConfirmationDialog({
    required this.library,
    required this.paths,
    this.targetAlbum,
    super.key,
  });

  final LibraryController library;
  final List<String> paths;
  final AlbumSummary? targetAlbum;

  @override
  State<ImportConfirmationDialog> createState() =>
      _ImportConfirmationDialogState();
}

class _ImportConfirmationDialogState extends State<ImportConfirmationDialog> {
  late final Future<List<ImportCandidate>> future;
  List<ImportCandidate>? candidates;

  @override
  void initState() {
    super.initState();
    future = widget.library.prepareImportCandidates(widget.paths);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ImportCandidate>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            candidates == null) {
          final loaded = snapshot.data ?? const <ImportCandidate>[];
          candidates = [
            for (final candidate in loaded)
              widget.targetAlbum == null
                  ? candidate
                  : candidateForAlbum(candidate, widget.targetAlbum!),
          ];
        }
        final current = candidates ?? const <ImportCandidate>[];
        return AlertDialog(
          backgroundColor: CanaryTheme.background,
          title: const Text('Confirm Metadata'),
          content: SizedBox(
            width: 760,
            height: 460,
            child: snapshot.connectionState != ConnectionState.done
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: current.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => ImportCandidateCard(
                      candidate: current[index],
                      onEdit: () async {
                        final updated = await showMetadataCorrectionDialog(
                          context,
                          widget.library,
                          current[index],
                        );
                        if (updated == null) return;
                        setState(() => candidates![index] = updated);
                      },
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: current.isEmpty
                  ? null
                  : () async {
                      var policy = DuplicateImportPolicy.keepBoth;
                      final duplicateCount = current
                          .where(
                            (candidate) =>
                                widget.library.duplicateForCandidate(
                                  candidate,
                                ) !=
                                null,
                          )
                          .length;
                      if (duplicateCount > 0) {
                        final selected = await showDuplicateImportDialog(
                          context,
                          duplicateCount,
                        );
                        if (selected == null) return;
                        policy = selected;
                      }
                      await widget.library.acceptImportCandidates(
                        current,
                        duplicatePolicy: policy,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
              child: Text('Accept ${current.length}'),
            ),
          ],
        );
      },
    );
  }
}

Future<DuplicateImportPolicy?> showDuplicateImportDialog(
  BuildContext context,
  int duplicateCount,
) {
  return showDialog<DuplicateImportPolicy>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: CanaryTheme.background,
      title: const Text('Already in Canary'),
      content: Text(
        '$duplicateCount selected song${duplicateCount == 1 ? '' : 's'} look like they are already in Canary. What should happen?',
        style: const TextStyle(color: CanaryTheme.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, DuplicateImportPolicy.skip),
          child: const Text('Skip'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, DuplicateImportPolicy.keepBoth),
          child: const Text('Keep Both'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, DuplicateImportPolicy.replace),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
}

class ImportCandidateCard extends StatelessWidget {
  const ImportCandidateCard({
    required this.candidate,
    required this.onEdit,
    super.key,
  });

  final ImportCandidate candidate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final draft = candidate.draft;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CanaryTheme.border),
      ),
      child: Row(
        children: [
          CoverPreview(coverUrl: draft?.coverUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: CanaryTheme.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Current: ${candidate.currentArtist} - ${candidate.currentTitle}',
                  style: const TextStyle(color: CanaryTheme.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  'Suggested: ${draft?.artist ?? 'Unknown'} - ${draft?.title ?? 'No match'}',
                  style: const TextStyle(color: CanaryTheme.text),
                ),
                Text(
                  '${draft?.album ?? 'Single'} • ${draft?.genre ?? 'Unsorted'} • ${draft?.sourceLabel ?? candidate.status} • ${(((draft?.confidence ?? 0) * 100).round())}%',
                  style: const TextStyle(
                    color: CanaryTheme.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Correct metadata',
          ),
        ],
      ),
    );
  }
}

Future<ImportCandidate?> showMetadataCorrectionDialog(
  BuildContext context,
  LibraryController library,
  ImportCandidate candidate,
) async {
  return showDialog<ImportCandidate>(
    context: context,
    builder: (context) =>
        MetadataCorrectionDialog(library: library, candidate: candidate),
  );
}

class MetadataCorrectionDialog extends StatefulWidget {
  const MetadataCorrectionDialog({
    required this.library,
    required this.candidate,
    super.key,
  });

  final LibraryController library;
  final ImportCandidate candidate;

  @override
  State<MetadataCorrectionDialog> createState() =>
      _MetadataCorrectionDialogState();
}

class ExistingAlbumChoice {
  const ExistingAlbumChoice({
    required this.key,
    required this.title,
    required this.artist,
    required this.trackCount,
  });

  final String key;
  final String title;
  final String artist;
  final int trackCount;
}

class _MetadataCorrectionDialogState extends State<MetadataCorrectionDialog> {
  late final TextEditingController queryController;
  late final TextEditingController titleController;
  late final TextEditingController artistController;
  late final TextEditingController albumController;
  late final TextEditingController genreController;
  MetadataDraft? selectedDraft;
  List<MetadataDraft> options = const [];
  bool loading = false;
  bool albumLoading = false;
  bool isAlbumRelease = false;
  String? selectedExistingAlbumKey;
  int searchSerial = 0;

  List<ExistingAlbumChoice> get existingAlbums {
    final grouped = <String, List<CanaryTrack>>{};
    for (final track in widget.library.currentTracks) {
      if (isSingleAlbum(track.album)) continue;
      final key = normalizeAlbumKey(track.displayAlbum);
      grouped.putIfAbsent(key, () => []).add(track);
    }
    final albums =
        grouped.entries.map((entry) {
          final first = entry.value.first;
          return ExistingAlbumChoice(
            key: entry.key,
            title: first.displayAlbum,
            artist: first.displayArtist,
            trackCount: entry.value.length,
          );
        }).toList()..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    return albums;
  }

  @override
  void initState() {
    super.initState();
    queryController = TextEditingController(
      text:
          '${widget.candidate.currentArtist} - ${widget.candidate.currentTitle}',
    );
    selectedDraft = widget.candidate.draft;
    titleController = TextEditingController(
      text: selectedDraft?.title ?? widget.candidate.currentTitle,
    );
    artistController = TextEditingController(
      text: selectedDraft?.artist ?? widget.candidate.currentArtist,
    );
    albumController = TextEditingController(
      text: selectedDraft?.album ?? 'Single',
    );
    genreController = TextEditingController(
      text: selectedDraft?.genre ?? 'Unsorted',
    );
    isAlbumRelease = !isSingleAlbum(albumController.text);
    selectedExistingAlbumKey = _matchingExistingAlbumKey();
    unawaited(search());
  }

  @override
  void dispose() {
    queryController.dispose();
    titleController.dispose();
    artistController.dispose();
    albumController.dispose();
    genreController.dispose();
    super.dispose();
  }

  void applyDraftToFields(MetadataDraft draft) {
    titleController.text = draft.title;
    artistController.text = draft.artist;
    albumController.text = draft.album;
    genreController.text = draft.genre;
    isAlbumRelease = !isSingleAlbum(draft.album);
    selectedExistingAlbumKey = _matchingExistingAlbumKey();
  }

  String? _matchingExistingAlbumKey() {
    if (!isAlbumRelease) return null;
    final key = normalizeAlbumKey(albumController.text);
    return existingAlbums.any((album) => album.key == key) ? key : null;
  }

  ExistingAlbumChoice? _existingAlbumForKey(String? albumKey) {
    if (albumKey == null) return null;
    for (final album in existingAlbums) {
      if (album.key == albumKey) return album;
    }
    return null;
  }

  void applyExistingAlbum(String? albumKey) {
    final album = _existingAlbumForKey(albumKey);
    setState(() {
      selectedExistingAlbumKey = albumKey;
      if (album != null) {
        isAlbumRelease = true;
        albumController.text = album.title;
      }
    });
  }

  MetadataDraft manualDraft() {
    final fallback = selectedDraft ?? widget.candidate.draft;
    return MetadataDraft(
      title: titleController.text.trim().isEmpty
          ? widget.candidate.currentTitle
          : titleController.text.trim(),
      artist: artistController.text.trim().isEmpty
          ? widget.candidate.currentArtist
          : artistController.text.trim(),
      album: isAlbumRelease
          ? (albumController.text.trim().isEmpty
                ? 'Unknown Album'
                : albumController.text.trim())
          : 'Single',
      genre: genreController.text.trim().isEmpty
          ? 'Unsorted'
          : genreController.text.trim(),
      confidence: fallback?.confidence ?? .72,
      coverUrl: fallback?.coverUrl,
      sourceLabel: fallback == null
          ? 'Manual correction'
          : '${fallback.sourceLabel} + manual correction',
      releaseId: fallback?.releaseId,
      artistImageUrl: fallback?.artistImageUrl,
    );
  }

  Future<void> search() async {
    final serial = ++searchSerial;
    setState(() => loading = true);
    try {
      final next = await widget.library.previewMetadataOptions(
        songQuery: queryController.text,
      );
      if (!mounted || serial != searchSerial) return;
      setState(() {
        options = next;
        if (options.isNotEmpty) {
          selectedDraft = options.first;
          applyDraftToFields(options.first);
        }
        loading = false;
      });
    } catch (_) {
      if (!mounted || serial != searchSerial) return;
      setState(() {
        options = const [];
        loading = false;
      });
    }
  }

  Future<void> matchAlbum() async {
    if (!isAlbumRelease ||
        albumController.text.trim().isEmpty ||
        albumLoading) {
      return;
    }
    setState(() => albumLoading = true);
    try {
      final draft = await widget.library.previewAlbumMetadata(
        title: titleController.text,
        artist: artistController.text,
        album: albumController.text,
        fallback: manualDraft(),
      );
      if (!mounted) return;
      setState(() {
        if (draft != null) {
          selectedDraft = draft;
          options = [
            draft,
            ...options.where(
              (option) =>
                  option.sourceLabel != draft.sourceLabel ||
                  option.album != draft.album ||
                  option.title != draft.title,
            ),
          ].take(5).toList();
          applyDraftToFields(draft);
        }
        albumLoading = false;
      });
      if (draft == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No album match found. Try the exact album title and artist.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => albumLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Album lookup failed. Try again with a clearer album title.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CanaryTheme.background,
      title: const Text('Correct Metadata'),
      content: SizedBox(
        width: 760,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: queryController,
              decoration: InputDecoration(
                labelText: 'Search artist and song',
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: loading ? null : search,
                ),
              ),
              onSubmitted: (_) {
                if (!loading) unawaited(search());
              },
            ),
            const SizedBox(height: 14),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : options.isEmpty
                  ? const Center(
                      child: Text(
                        'No matches. Try a different artist or song name.',
                        style: TextStyle(color: CanaryTheme.muted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: options.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final draft = options[index];
                        final selected = identical(draft, selectedDraft);
                        return InkWell(
                          onTap: () => setState(() {
                            selectedDraft = draft;
                            applyDraftToFields(draft);
                          }),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? CanaryTheme.honey.withValues(alpha: .62)
                                  : Colors.white.withValues(alpha: .70),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? CanaryTheme.amber
                                    : CanaryTheme.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                CoverPreview(coverUrl: draft.coverUrl),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${draft.title}\n${draft.artist} • ${draft.album} • ${draft.genre}\n${draft.sourceLabel} • ${(draft.confidence * 100).round()}%',
                                    style: const TextStyle(
                                      color: CanaryTheme.text,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: CanaryTheme.amber,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: artistController,
                    decoration: const InputDecoration(labelText: 'Artist'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Single'),
                      icon: Icon(Icons.music_note_rounded),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Album'),
                      icon: Icon(Icons.album_rounded),
                    ),
                  ],
                  selected: {isAlbumRelease},
                  onSelectionChanged: (selection) {
                    setState(() {
                      isAlbumRelease = selection.first;
                      if (!isAlbumRelease) {
                        albumController.text = 'Single';
                        selectedExistingAlbumKey = null;
                      } else if (isSingleAlbum(albumController.text)) {
                        albumController.clear();
                      }
                    });
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: albumController,
                          enabled: isAlbumRelease,
                          decoration: InputDecoration(
                            labelText: isAlbumRelease
                                ? 'Album title'
                                : 'Standalone single',
                          ),
                          onChanged: (_) {
                            final match = _matchingExistingAlbumKey();
                            if (match != selectedExistingAlbumKey) {
                              setState(() => selectedExistingAlbumKey = match);
                            }
                          },
                        ),
                      ),
                      if (isAlbumRelease && existingAlbums.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 226,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(
                              selectedExistingAlbumKey ?? 'new-album',
                            ),
                            initialValue: selectedExistingAlbumKey,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Existing album',
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('New album'),
                              ),
                              ...existingAlbums.map(
                                (album) => DropdownMenuItem<String>(
                                  value: album.key,
                                  child: Text(
                                    '${album.title} - ${album.artist}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            selectedItemBuilder: (context) => [
                              const Text('New album'),
                              ...existingAlbums.map(
                                (album) => Text(
                                  album.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            onChanged: applyExistingAlbum,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Match album cover and title',
                  onPressed: isAlbumRelease && !albumLoading
                      ? () => unawaited(matchAlbum())
                      : null,
                  icon: albumLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.manage_search_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: genreController,
                    decoration: const InputDecoration(labelText: 'Genre'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            widget.candidate.copyWith(
              draft: manualDraft(),
              status: 'Manually corrected',
            ),
          ),
          child: const Text('Use Details'),
        ),
      ],
    );
  }
}

Future<void> showAddSongDialog(
  BuildContext context,
  LibraryController library,
) async {
  final songController = TextEditingController();
  final youtubeController = TextEditingController();
  MetadataDraft? draft;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: CanaryTheme.background,
        title: const Text('Song Lookup'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: youtubeController,
                decoration: const InputDecoration(labelText: 'YouTube link'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: songController,
                decoration: const InputDecoration(
                  labelText: 'Song name or Artist - Song',
                ),
              ),
              const SizedBox(height: 18),
              if (draft != null) MetadataDraftPreview(draft: draft!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final next = await library.previewMetadata(
                songQuery: songController.text,
                youtubeUrl: youtubeController.text,
              );
              setState(() => draft = next);
            },
            child: const Text('Preview Metadata'),
          ),
          FilledButton(
            onPressed: () async {
              await library.addSong(
                songQuery: songController.text,
                youtubeUrl: youtubeController.text,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showAlbumImportDialog(
  BuildContext context,
  LibraryController library,
) async {
  final playlistController = TextEditingController();
  AlbumDraft? draft;
  var loading = false;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: CanaryTheme.background,
        title: const Text('YouTube Playlist Album'),
        content: SizedBox(
          width: 820,
          height: 520,
          child: Column(
            children: [
              TextField(
                controller: playlistController,
                decoration: const InputDecoration(
                  labelText: 'YouTube playlist URL',
                ),
              ),
              const SizedBox(height: 16),
              if (draft == null)
                Expanded(
                  child: Center(
                    child: loading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'Fetch a playlist draft, then map each metadata row to the correct local audio file.',
                            style: TextStyle(color: CanaryTheme.muted),
                          ),
                  ),
                )
              else
                Expanded(
                  child: AlbumMappingList(
                    draft: draft!,
                    onChanged: (next) => setState(() => draft = next),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: loading
                ? null
                : () async {
                    setState(() => loading = true);
                    final next = await library.prepareAlbumDraft(
                      playlistController.text,
                    );
                    setState(() {
                      draft = next;
                      loading = false;
                    });
                  },
            child: const Text('Fetch Draft'),
          ),
          FilledButton(
            onPressed:
                draft == null ||
                    !draft!.tracks.any((track) => track.mappedFilePath != null)
                ? null
                : () async {
                    await library.acceptAlbumDraft(draft!);
                    if (context.mounted) Navigator.pop(context);
                  },
            child: const Text('Import Mapped Songs'),
          ),
        ],
      ),
    ),
  );
}

class AlbumMappingList extends StatelessWidget {
  const AlbumMappingList({
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final AlbumDraft draft;
  final ValueChanged<AlbumDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          draft.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: CanaryTheme.text,
          ),
        ),
        Text(
          draft.sourceUrl,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: CanaryTheme.muted),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: draft.tracks.isEmpty
              ? const Center(
                  child: Text(
                    'No playlist tracks were found. Check that yt-dlp can access this playlist URL.',
                    style: TextStyle(color: CanaryTheme.muted),
                  ),
                )
              : ListView.separated(
                  itemCount: draft.tracks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final track = draft.tracks[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .70),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CanaryTheme.border),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 34,
                            child: Text(
                              '${track.index}'.padLeft(2, '0'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: CanaryTheme.faint,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${track.artist} - ${track.title}',
                              style: const TextStyle(
                                color: CanaryTheme.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 230,
                            child: Text(
                              track.mappedFilePath
                                      ?.split(Platform.pathSeparator)
                                      .last ??
                                  'No file selected',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: CanaryTheme.muted),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Select matching audio file',
                            icon: const Icon(Icons.file_open_rounded),
                            onPressed: () async {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: const [
                                      'mp3',
                                      'flac',
                                      'aac',
                                      'm4a',
                                      'ogg',
                                      'wav',
                                      'opus',
                                    ],
                                  );
                              final path = result?.paths
                                  .whereType<String>()
                                  .firstOrNull;
                              if (path == null) return;
                              final tracks = [...draft.tracks];
                              tracks[index] = track.copyWith(
                                mappedFilePath: path,
                              );
                              onChanged(
                                AlbumDraft(
                                  id: draft.id,
                                  sourceUrl: draft.sourceUrl,
                                  title: draft.title,
                                  artist: draft.artist,
                                  coverUrl: draft.coverUrl,
                                  tracks: tracks,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class MetadataDraftPreview extends StatelessWidget {
  const MetadataDraftPreview({required this.draft, super.key});

  final MetadataDraft draft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CanaryTheme.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CanaryTheme.border),
      ),
      child: Row(
        children: [
          CoverPreview(coverUrl: draft.coverUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${draft.title}\n${draft.artist} • ${draft.album} • ${draft.genre}\n${draft.sourceLabel} • ${(draft.confidence * 100).round()}%',
              style: const TextStyle(color: CanaryTheme.text),
            ),
          ),
        ],
      ),
    );
  }
}
