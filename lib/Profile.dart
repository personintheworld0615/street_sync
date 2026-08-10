import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:street_sync/LoginScreen.dart';
import 'package:street_sync/MyDraftReportsScreen.dart';
import 'package:street_sync/MyReportsScreen.dart';
import 'package:street_sync/api_service.dart';
import 'package:street_sync/auth_service.dart';
import 'package:street_sync/error_popup.dart';
import 'package:street_sync/skeleton.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  static const _pageBg = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF8A8F98);
  static const _danger = Color(0xFF9B4D3C);

  bool pushNotifications = true;
  bool _isLoading = true;
  bool _uploadingPicture = false;
  String? _localPicturePath;
  List<Map<String, dynamic>> _draftReports = [];
  List<Map<String, dynamic>> _submittedReports = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserReports();
  }

  Future<void> _loadUserReports({bool forceNetwork = false}) async {
    final userId = ApiService.userId;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _draftReports = [];
        _submittedReports = [];
        _isLoading = false;
      });
      return;
    }

    if (!forceNetwork) {
      final cachedDrafts = await ApiService.getCachedDraftReports(userId);
      final cachedSubmitted =
          await ApiService.getCachedSubmittedReports(userId);
      if ((cachedDrafts != null || cachedSubmitted != null) && mounted) {
        setState(() {
          if (cachedDrafts != null) {
            _draftReports = cachedDrafts
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
          if (cachedSubmitted != null) {
            _submittedReports = cachedSubmitted
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
          _isLoading = false;
        });
      }
    }

    final results = await Future.wait([
      ApiService.getDraftReports(userId),
      ApiService.getSubmittedReports(userId),
    ]);
    if (!mounted) return;
    setState(() {
      _draftReports =
          results[0].map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _submittedReports =
          results[1].map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _isLoading = false;
    });
  }

  Future<void> _fetchUserReports() => _loadUserReports(forceNetwork: true);

  Future<void> _pickProfilePicture() async {
    if (_uploadingPicture) return;
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
    if (picked == null) return;

    setState(() {
      _localPicturePath = picked.path;
      _uploadingPicture = true;
    });

    final url = await ApiService.uploadProfilePicture(picked.path);
    if (!mounted) return;

    setState(() {
      _uploadingPicture = false;
      _localPicturePath = null;
    });

    if (url == null) {
      await showErrorPopup(
        context,
        'Could not upload profile picture. Please try again.',
      );
    }
  }

  Future<void> _signOut() async {
    await ApiService.logout();
    if (!mounted) return;
    if (!AuthService.isConfigured) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and reports. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final error = await ApiService.deleteAccount();
    if (!mounted) return;

    if (error != null) {
      await showErrorPopup(context, error);
      return;
    }

    if (!AuthService.isConfigured) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ProfileSkeleton();
    }

    final reportsCount = _submittedReports.length;
    final resolvedCount = _submittedReports.where((report) {
      final status = (report['status'] as String?)?.trim().toLowerCase();
      return status == 'resolved';
    }).length;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _pageBg,
      body: RefreshIndicator(
        onRefresh: _fetchUserReports,
        color: _ink,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            28,
            topInset + 24,
            28,
            120 + bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  _avatar(),
                  const SizedBox(height: 16),
                  Text(
                    _displayName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                      height: 1.1,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'West Windsor, NJ',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _muted,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$reportsCount reports  •  $resolvedCount resolved',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _muted,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              _actionRow(
                icon: Icons.description_outlined,
                label: 'My reports',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MyReportsScreen(reports: _submittedReports),
                    ),
                  );
                },
              ),
              _actionRow(
                icon: Icons.edit_square,
                label: 'Drafts',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MyDraftReportsScreen(reports: _draftReports),
                    ),
                  );
                },
              ),
              _actionRow(
                icon: Icons.notifications_none_rounded,
                label: 'Push notifications',
                trailing: _toggle(
                  value: pushNotifications,
                  onChanged: (v) => setState(() => pushNotifications = v),
                ),
              ),
              _actionRow(
                icon: Icons.shield_outlined,
                label: 'Privacy policy',
                onTap: () {},
              ),
              _actionRow(
                icon: Icons.logout_rounded,
                label: 'Sign out',
                color: _danger,
                onTap: _signOut,
              ),
              _actionRow(
                icon: Icons.delete_outline_rounded,
                label: 'Delete account',
                color: _danger,
                bold: true,
                onTap: _confirmDeleteAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _displayName {
    final raw = ApiService.userName.trim();
    if (raw.isEmpty) return 'You';
    return raw.split(RegExp(r'\s+')).first;
  }

  Widget _toggle({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      height: 30,
      child: Switch(
        value: value,
        activeThumbColor: Colors.white,
        activeTrackColor: _ink,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFD1D5DB),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: onChanged,
      ),
    );
  }

  Widget _avatar() {
    final localPath = _localPicturePath;
    final remoteUrl = ApiService.userPicture;
    final initial = _displayName.isNotEmpty
        ? _displayName.substring(0, 1).toUpperCase()
        : '?';

    Widget face;
    if (localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync()) {
      face = Image.file(
        File(localPath),
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      );
    } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
      face = Image.network(
        remoteUrl,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _initialFace(initial),
      );
    } else {
      face = _initialFace(initial);
    }

    return GestureDetector(
      onTap: _uploadingPicture ? null : _pickProfilePicture,
      child: SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(child: face),
            ),
            if (_uploadingPicture)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.35),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _initialFace(String initial) {
    return ColoredBox(
      color: const Color(0xFFE8EAED),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.playfairDisplay(
            fontSize: 46,
            fontWeight: FontWeight.w600,
            color: _muted,
          ),
        ),
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    Color color = _ink,
    bool bold = false,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: _ink.withValues(alpha: 0.04),
        highlightColor: _ink.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17),
          child: Row(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                    letterSpacing: -0.15,
                    height: 1.2,
                  ),
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
                    color: color == _danger
                        ? color.withValues(alpha: 0.45)
                        : const Color(0xFFB0B5BD),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
