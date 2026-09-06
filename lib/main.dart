import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'controllers/media_vault_controller.dart';
import 'screens/downloader_screen.dart';
import 'screens/batch_downloader_screen.dart';
import 'screens/library_screen.dart';
import 'screens/playlists_screen.dart';
import 'screens/history_screen.dart';
import 'widgets/media_player_modal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => MediaVaultController(),
      child: const MediaVaultApp(),
    ),
  );
}

class MediaVaultApp extends StatelessWidget {
  const MediaVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
          primary: const Color(0xFFD0BCFF),
          secondary: const Color(0xFFCCC2DC),
          surface: const Color(0xFF141218),
          surfaceContainer: const Color(0xFF1D1B20),
          surfaceContainerHigh: const Color(0xFF2B2930),
        ),
        scaffoldBackgroundColor: const Color(0xFF141218),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141218),
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF211F26),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1D1B20),
          indicatorColor: const Color(0xFF4A4458),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MediaVaultController>();

    final screens = [
      DownloaderScreen(onNavigateToLibrary: () => _navigateToTab(2)),
      BatchDownloaderScreen(onNavigateToLibrary: () => _navigateToTab(2)),
      LibraryScreen(onNavigateToDownloader: () => _navigateToTab(0)),
      PlaylistsScreen(onNavigateToLibrary: () => _navigateToTab(2)),
      HistoryScreen(onNavigateToDownloader: () => _navigateToTab(0)),
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),

          // Mini player bar if playing
          if (controller.currentlyPlayingMedia != null)
            _buildMiniPlayer(context, controller),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _navigateToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Download',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_play_next_outlined),
            selectedIcon: Icon(Icons.queue_play_next),
            label: 'Batch',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.playlist_play_outlined),
            selectedIcon: Icon(Icons.playlist_play),
            label: 'Playlists',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer(BuildContext context, MediaVaultController controller) {
    final media = controller.currentlyPlayingMedia!;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2B2930),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => MediaPlayerModal(
              media: media,
              controller: controller,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                media.isVideo ? Icons.videocam : Icons.audiotrack,
                color: const Color(0xFFD0BCFF),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      media.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      media.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(controller.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () => controller.togglePlayPause(),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => controller.closePlayer(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
