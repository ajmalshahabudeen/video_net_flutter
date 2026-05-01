import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/brutalist_theme.dart';
import '../widgets/brutalist_button.dart';
import '../widgets/brutalist_card.dart';
import '../widgets/brutalist_text_field.dart';
import 'file_browser_screen.dart';

/// Screen 2: Credentials & Share Selection
/// Prompts for username/password, connects, and lists available shares.
class CredentialsScreen extends StatefulWidget {
  final DiscoveredHost host;

  const CredentialsScreen({super.key, required this.host});

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _domainController = TextEditingController();
  bool _showDomain = false;
  bool _obscurePassword = true;
  bool _loadedSaved = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final state = context.read<AppState>();
    final saved = await state.getSavedCredentials(widget.host.ip);
    if (saved != null && mounted) {
      setState(() {
        _usernameController.text = saved.username;
        _passwordController.text = saved.password;
        _domainController.text = saved.domain;
        _showDomain = saved.domain.isNotEmpty;
        _loadedSaved = true;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final state = context.read<AppState>();
    final credentials = SmbCredentials(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      domain: _domainController.text.trim(),
    );

    final success = await state.connectToHost(credentials);

    if (success && mounted) {
      // If connected and shares found, show shares
      setState(() {});
    }
  }

  Future<void> _connectAsGuest() async {
    final state = context.read<AppState>();
    final success =
        await state.connectToHost(SmbCredentials.guest());

    if (success && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        onTap: () {
                          state.disconnectFromHost();
                          Navigator.pop(context);
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_back,
                                color: BrutalistTheme.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'BACK',
                              style:
                                  BrutalistTheme.labelLarge.copyWith(
                                color: BrutalistTheme.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'CONNECT//',
                        style: BrutalistTheme.displayMedium.copyWith(
                          color: BrutalistTheme.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        color: BrutalistTheme.accent,
                        child: Text(
                          widget.host.ip,
                          style: BrutalistTheme.mono.copyWith(
                            color: BrutalistTheme.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── CONTENT ─────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: state.isConnected
                        ? _buildShareList(state)
                        : _buildLoginForm(state),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginForm(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Saved credentials indicator
        if (_loadedSaved)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BrutalistTheme.success.withValues(alpha: 0.1),
              border: Border.all(
                  color: BrutalistTheme.success, width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.save,
                    color: BrutalistTheme.success, size: 16),
                const SizedBox(width: 8),
                Text(
                  'SAVED CREDENTIALS LOADED',
                  style: BrutalistTheme.bodySmall.copyWith(
                    color: BrutalistTheme.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

        // Username
        BrutalistTextField(
          controller: _usernameController,
          label: 'USERNAME',
          hint: 'admin',
          prefixIcon: Icons.person,
        ),
        const SizedBox(height: 16),

        // Password
        BrutalistTextField(
          controller: _passwordController,
          label: 'PASSWORD',
          hint: '••••••••',
          obscureText: _obscurePassword,
          prefixIcon: Icons.lock,
          suffix: GestureDetector(
            onTap: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword
                  ? Icons.visibility_off
                  : Icons.visibility,
              size: 18,
              color: BrutalistTheme.darkConcrete,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Domain toggle
        GestureDetector(
          onTap: () => setState(() => _showDomain = !_showDomain),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _showDomain
                      ? BrutalistTheme.black
                      : BrutalistTheme.white,
                  border: BrutalistTheme.hardBorder,
                ),
                child: _showDomain
                    ? const Icon(Icons.check,
                        size: 10, color: BrutalistTheme.white)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                'SPECIFY DOMAIN',
                style: BrutalistTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),

        // Domain field
        if (_showDomain) ...[
          const SizedBox(height: 12),
          BrutalistTextField(
            controller: _domainController,
            label: 'DOMAIN',
            hint: 'WORKGROUP',
            prefixIcon: Icons.domain,
          ),
        ],

        const SizedBox(height: 24),

        // Error
        if (state.connectionError != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: BrutalistTheme.error.withValues(alpha: 0.1),
              border: Border.all(
                  color: BrutalistTheme.error, width: 3),
            ),
            child: Text(
              state.connectionError!,
              style: BrutalistTheme.mono.copyWith(
                color: BrutalistTheme.error,
                fontSize: 11,
              ),
            ),
          ),
        ],

        // Connect button
        BrutalistButton(
          label: 'CONNECT >>',
          icon: Icons.login,
          backgroundColor: BrutalistTheme.accent,
          isLoading: state.isConnecting,
          onPressed: state.isConnecting ? null : _connect,
        ),

        const SizedBox(height: 12),

        // Guest button
        BrutalistButton(
          label: 'TRY GUEST ACCESS',
          icon: Icons.person_outline,
          backgroundColor: BrutalistTheme.white,
          textColor: BrutalistTheme.black,
          isLoading: state.isConnecting,
          onPressed: state.isConnecting ? null : _connectAsGuest,
        ),
      ],
    );
  }

  Widget _buildShareList(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BrutalistTheme.success.withValues(alpha: 0.1),
            border:
                Border.all(color: BrutalistTheme.success, width: 3),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: BrutalistTheme.success,
                  border: Border.all(
                      color: BrutalistTheme.black, width: 2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'CONNECTED',
                style: BrutalistTheme.labelLarge.copyWith(
                  color: BrutalistTheme.success,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Shares header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              color: BrutalistTheme.black,
              child: Text(
                'SHARES: ${state.shares.length}',
                style: BrutalistTheme.labelLarge.copyWith(
                  color: BrutalistTheme.accent,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(height: 3, color: BrutalistTheme.black),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (state.shares.isEmpty)
          BrutalistCard(
            backgroundColor: BrutalistTheme.concrete,
            child: Center(
              child: Text(
                'NO ACCESSIBLE SHARES FOUND',
                style: BrutalistTheme.bodySmall,
              ),
            ),
          ),

        // Share list
        ...state.shares.map((share) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: BrutalistCard(
                onTap: () async {
                  await state.openShare(share);
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FileBrowserScreen(shareName: share),
                      ),
                    );
                  }
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: BrutalistTheme.warning,
                      child: const Icon(
                        Icons.folder_shared,
                        color: BrutalistTheme.black,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        share,
                        style: BrutalistTheme.headlineMedium,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: BrutalistTheme.black,
                      child: const Icon(
                        Icons.arrow_forward,
                        color: BrutalistTheme.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            )),

        const SizedBox(height: 16),

        // Disconnect
        BrutalistButton(
          label: 'DISCONNECT',
          icon: Icons.logout,
          backgroundColor: BrutalistTheme.darkConcrete,
          onPressed: () {
            state.disconnectFromHost();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
