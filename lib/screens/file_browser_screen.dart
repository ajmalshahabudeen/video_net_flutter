import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/brutalist_theme.dart';
import '../widgets/brutalist_card.dart';
import 'video_player_screen.dart';

/// Screen 3: File Browser
/// Browses files and folders on the selected SMB share.
class FileBrowserScreen extends StatelessWidget {
  final String shareName;

  const FileBrowserScreen({super.key, required this.shareName});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final state = context.read<AppState>();
        final navigated = await state.navigateBack();
        if (!navigated && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: BrutalistTheme.concrete,
        body: SafeArea(
          child: Consumer<AppState>(
            builder: (context, state, _) {
              return Column(
                children: [
                  // ─── HEADER ──────────────────
                  Container(
                    width: double.infinity,
                    color: BrutalistTheme.black,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final navigated =
                                await state.navigateBack();
                            if (!navigated && context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_back,
                                  color: BrutalistTheme.white,
                                  size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'BACK',
                                style: BrutalistTheme.labelLarge
                                    .copyWith(
                                  color: BrutalistTheme.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'BROWSE//',
                          style:
                              BrutalistTheme.displayMedium.copyWith(
                            color: BrutalistTheme.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── BREADCRUMB ──────────────
                  _BreadcrumbBar(
                    shareName: shareName,
                    currentPath: state.currentPath,
                  ),

                  // ─── FILE LIST ───────────────
                  Expanded(
                    child: state.isLoadingFiles
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: BrutalistTheme.accent,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'LOADING...',
                                  style: BrutalistTheme.labelLarge,
                                ),
                              ],
                            ),
                          )
                        : state.browseError != null
                            ? _ErrorView(error: state.browseError!)
                            : state.files.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.folder_open,
                                          size: 64,
                                          color: BrutalistTheme
                                              .darkConcrete,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'EMPTY DIRECTORY',
                                          style: BrutalistTheme
                                              .headlineMedium,
                                        ),
                                      ],
                                    ),
                                  )
                                : _FileList(files: state.files),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Breadcrumb navigation bar.
class _BreadcrumbBar extends StatelessWidget {
  final String shareName;
  final String currentPath;

  const _BreadcrumbBar({
    required this.shareName,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    final pathSegments = currentPath
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: BrutalistTheme.darkConcrete,
        border: const Border(
          bottom: BorderSide(color: BrutalistTheme.black, width: 3),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.storage,
                color: BrutalistTheme.accent, size: 14),
            const SizedBox(width: 6),
            Text(
              '/$shareName',
              style: BrutalistTheme.mono.copyWith(
                color: BrutalistTheme.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            ...pathSegments.map((seg) => Row(
                  children: [
                    Text(
                      ' / ',
                      style: BrutalistTheme.mono.copyWith(
                        color: BrutalistTheme.concrete
                            .withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      seg,
                      style: BrutalistTheme.mono.copyWith(
                        color: BrutalistTheme.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}

/// File list view.
class _FileList extends StatelessWidget {
  final List<SmbFileInfo> files;

  const _FileList({required this.files});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return _FileItem(file: file);
      },
    );
  }
}

/// Individual file/folder item.
class _FileItem extends StatelessWidget {
  final SmbFileInfo file;

  const _FileItem({required this.file});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();

    IconData icon;
    Color iconBg;
    Color iconColor;

    if (file.isDirectory) {
      icon = Icons.folder;
      iconBg = BrutalistTheme.warning;
      iconColor = BrutalistTheme.black;
    } else if (file.isVideo) {
      icon = Icons.play_circle_filled;
      iconBg = BrutalistTheme.accent;
      iconColor = BrutalistTheme.white;
    } else {
      icon = Icons.insert_drive_file;
      iconBg = BrutalistTheme.concrete;
      iconColor = BrutalistTheme.darkConcrete;
    }

    final isInteractive = file.isDirectory || file.isVideo;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: BrutalistCard(
        backgroundColor: isInteractive
            ? BrutalistTheme.white
            : BrutalistTheme.concrete.withValues(alpha: 0.7),
        showShadow: isInteractive,
        onTap: isInteractive
            ? () async {
                if (file.isDirectory) {
                  // Extract relative path for navigation
                  final dirPath = _getRelativePath(
                      file.path, state.currentShare!);
                  await state.openDirectory(dirPath);
                } else if (file.isVideo) {
                  _openVideo(context, state, file);
                }
              }
            : null,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                border: Border.all(
                    color: BrutalistTheme.black, width: 2),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),

            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: BrutalistTheme.bodyMedium.copyWith(
                      fontWeight: isInteractive
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isInteractive
                          ? BrutalistTheme.black
                          : BrutalistTheme.darkConcrete,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!file.isDirectory) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          file.formattedSize,
                          style:
                              BrutalistTheme.bodySmall.copyWith(
                            fontSize: 11,
                          ),
                        ),
                        if (file.isVideo) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: BrutalistTheme.accent,
                              border: Border.all(
                                  color: BrutalistTheme.black,
                                  width: 1),
                            ),
                            child: Text(
                              file.extension
                                  .replaceAll('.', '')
                                  .toUpperCase(),
                              style: BrutalistTheme.bodySmall
                                  .copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: BrutalistTheme.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Action indicator
            if (file.isDirectory)
              Container(
                padding: const EdgeInsets.all(6),
                color: BrutalistTheme.black,
                child: const Icon(Icons.arrow_forward,
                    color: BrutalistTheme.white, size: 16),
              )
            else if (file.isVideo)
              Container(
                padding: const EdgeInsets.all(6),
                color: BrutalistTheme.accent,
                child: const Icon(Icons.play_arrow,
                    color: BrutalistTheme.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  String _getRelativePath(String fullPath, String shareName) {
    // fullPath is like /shareName/path/to/dir
    // We need to extract /path/to/dir
    final normalized = fullPath.replaceAll('\\', '/');
    final sharePrefix = '/$shareName';
    if (normalized.startsWith(sharePrefix)) {
      final relative = normalized.substring(sharePrefix.length);
      return relative.isEmpty ? '/' : relative;
    }
    return normalized;
  }

  Future<void> _openVideo(
    BuildContext context,
    AppState state,
    SmbFileInfo file,
  ) async {
    // Collect all video files in the current directory for next/prev
    final allFiles = state.files;
    final videoFiles = allFiles.where((f) => f.isVideo).toList();
    final currentIndex = videoFiles.indexWhere((f) => f.path == file.path);

    _openVideoAtIndex(context, state, videoFiles, currentIndex);
  }

  static Future<void> _openVideoAtIndex(
    BuildContext context,
    AppState state,
    List<SmbFileInfo> videoFiles,
    int index,
  ) async {
    if (index < 0 || index >= videoFiles.length) return;
    final file = videoFiles[index];

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: BrutalistTheme.white,
            border: BrutalistTheme.thickBorder,
            boxShadow: BrutalistTheme.hardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: BrutalistTheme.accent,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'PREPARING STREAM...',
                style: BrutalistTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Text(
                file.name,
                style: BrutalistTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );

    final url = await state.prepareVideo(file);

    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog

      if (url != null) {
        // Replace the current video player screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (ctx) => VideoPlayerScreen(
              videoUrl: url,
              videoName: file.name,
              onNextVideo: index < videoFiles.length - 1
                  ? () => _openVideoAtIndex(
                      ctx, state, videoFiles, index + 1)
                  : null,
              onPreviousVideo: index > 0
                  ? () => _openVideoAtIndex(
                      ctx, state, videoFiles, index - 1)
                  : null,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BrutalistTheme.error,
            content: Text(
              'FAILED TO PREPARE VIDEO STREAM',
              style: BrutalistTheme.mono
                  .copyWith(color: BrutalistTheme.white),
            ),
          ),
        );
      }
    }
  }
}

/// Error display widget.
class _ErrorView extends StatelessWidget {
  final String error;

  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: BrutalistTheme.error.withValues(alpha: 0.1),
          border: Border.all(color: BrutalistTheme.error, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: BrutalistTheme.error),
            const SizedBox(height: 16),
            Text(
              error,
              style: BrutalistTheme.mono.copyWith(
                color: BrutalistTheme.error,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
