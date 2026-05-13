import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/brutalist_theme.dart';
import '../widgets/brutalist_card.dart';
import 'video_player_screen.dart';

/// Screen 3: File Browser
/// Browses files and folders on the selected SMB share.
/// Supports list and grid view with video thumbnails.
class FileBrowserScreen extends StatefulWidget {
  final String shareName;

  const FileBrowserScreen({super.key, required this.shareName});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  bool _isGridView = false;

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
                        Row(
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
                            const Spacer(),
                            // ─── VIEW TOGGLE ─────
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _isGridView = !_isGridView),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: BrutalistTheme.white, width: 2),
                                ),
                                child: Icon(
                                  _isGridView
                                      ? Icons.view_list
                                      : Icons.grid_view,
                                  color: BrutalistTheme.accent,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
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
                    shareName: widget.shareName,
                    currentPath: state.currentPath,
                  ),

                  // ─── FILE LIST / GRID ─────────
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
                                : _isGridView
                                    ? _FileGrid(files: state.files)
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

/// File grid view.
class _FileGrid extends StatelessWidget {
  final List<SmbFileInfo> files;

  const _FileGrid({required this.files});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return _FileGridItem(file: file);
      },
    );
  }
}

/// Grid item for a file/folder.
class _FileGridItem extends StatelessWidget {
  final SmbFileInfo file;

  const _FileGridItem({required this.file});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final isInteractive = file.isDirectory || file.isVideo;

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

    return BrutalistCard(
      backgroundColor: isInteractive
          ? BrutalistTheme.white
          : BrutalistTheme.concrete.withValues(alpha: 0.7),
      showShadow: isInteractive,
      onTap: isInteractive
          ? () async {
              if (file.isDirectory) {
                final dirPath =
                    _getRelativePath(file.path, state.currentShare!);
                await state.openDirectory(dirPath);
              } else if (file.isVideo) {
                _FileItem._openVideo(context, state, file);
              }
            }
          : null,
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Thumbnail area
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: file.isVideo
                    ? BrutalistTheme.black
                    : iconBg.withValues(alpha: 0.15),
                border: Border.all(color: BrutalistTheme.black, width: 2),
              ),
              child: file.isVideo
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        // Video icon as thumbnail placeholder
                        Icon(Icons.movie, color: BrutalistTheme.darkConcrete, size: 40),
                        // Play overlay
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: BrutalistTheme.accent.withValues(alpha: 0.9),
                            border: Border.all(
                                color: BrutalistTheme.white, width: 2),
                          ),
                          child: const Icon(Icons.play_arrow,
                              color: BrutalistTheme.white, size: 20),
                        ),
                        // Format badge
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            color: BrutalistTheme.accent,
                            child: Text(
                              file.extension
                                  .replaceAll('.', '')
                                  .toUpperCase(),
                              style: BrutalistTheme.bodySmall.copyWith(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: BrutalistTheme.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Icon(icon, color: iconColor, size: 36),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          // File name
          Text(
            file.name,
            style: BrutalistTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (!file.isDirectory) ...[
            const SizedBox(height: 2),
            Text(
              file.formattedSize,
              style: BrutalistTheme.bodySmall.copyWith(fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  String _getRelativePath(String fullPath, String shareName) {
    final normalized = fullPath.replaceAll('\\', '/');
    final sharePrefix = '/$shareName';
    if (normalized.startsWith(sharePrefix)) {
      final relative = normalized.substring(sharePrefix.length);
      return relative.isEmpty ? '/' : relative;
    }
    return normalized;
  }
}

/// Individual file/folder item (list view).
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
    final normalized = fullPath.replaceAll('\\', '/');
    final sharePrefix = '/$shareName';
    if (normalized.startsWith(sharePrefix)) {
      final relative = normalized.substring(sharePrefix.length);
      return relative.isEmpty ? '/' : relative;
    }
    return normalized;
  }

  static Future<void> _openVideo(
    BuildContext context,
    AppState state,
    SmbFileInfo file,
  ) async {
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
