import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'main.dart';
import 'analytics_page.dart';
import 'repositories/partner_application_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/gust_card.dart';
import 'utils/notification_helper.dart';
import 'services/partner_access_api.dart';
import 'state/auth_state.dart';
import 'repositories/auth_repository.dart';
import 'sugar_log_creation_dialog.dart';

class PartnerAccessPage extends StatefulWidget {
  const PartnerAccessPage({super.key});

  @override
  State<PartnerAccessPage> createState() => _PartnerAccessPageState();
}

class _PartnerAccessPageState extends State<PartnerAccessPage> {
  final PartnerAccessApi _api = const PartnerAccessApi();
  final AuthRepository _authRepository = AuthRepository();
  final TextEditingController _ownerSearchController = TextEditingController();
  final TextEditingController _expertiseController = TextEditingController();
  final TextEditingController _motivationController = TextEditingController();
  Timer? _ownerSearchDebounce;
  List<PartnerOwnerSuggestion> _ownerSuggestions = [];
  PartnerOwnerSuggestion? _selectedOwner;

  final String _selectedModule = 'ANALYTICS';
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isApplying = false;
  bool _preference = true;
  String? _applicationStatus;
  String? _error;
  String _role = 'USER';
  String _userEmail = '';
  String _userName = '';
  int? _userId;

  List<PartnerAccessEntry> _incoming = [];
  List<PartnerAccessEntry> _outgoing = [];
  List<PartnerAccessEntry> _assignments = [];
  List<PartnerApplicationRecord> _applications = [];

  bool get _isGuest =>
      _role.toUpperCase() == 'ANONYMOUS' || _role.toUpperCase() == 'GUEST';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _ownerSearchDebounce?.cancel();
    _ownerSearchController.dispose();
    _expertiseController.dispose();
    _motivationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authState = context.read<AuthState>();
    final user = authState.currentUser;
    _role = user?.role ?? 'USER';
    _userEmail = user?.email ?? '';
    _userName = user?.fullName ?? _userEmail;
    _userId = user?.id;

    if (_userEmail.isEmpty) {
      final fallback = await _authRepository.getActiveUser();
      if (fallback != null && fallback.email.isNotEmpty) {
        _userEmail = fallback.email;
        _userName =
            fallback.fullName.isNotEmpty ? fallback.fullName : fallback.email;
        _userId = fallback.id;
      }
    }

    if (_userEmail.isEmpty) {
      setState(() {
        _error = 'Profile is missing an email address.';
        _isLoading = false;
      });
      return;
    }

    if (_isGuest) {
      setState(() {
        _incoming = [];
        _outgoing = [];
        _assignments = [];
        _error = 'Guests cannot manage partners. Upgrade to a full account.';
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final overview = await _api.fetchOverview();
      setState(() {
        _incoming = overview.incoming;
        _outgoing = overview.outgoing;
        _assignments = overview.assignments;
        _preference = overview.allowRequests;
        _applicationStatus = overview.applicationStatus;
        if (overview.lastApplication != null) {
          _expertiseController.text = overview.lastApplication!.expertise;
          _motivationController.text = overview.lastApplication!.motivation;
        }
        _error = null;
      });
      if (_role == 'ADMIN') {
        final apps = await _api.fetchApplications();
        setState(() {
          _applications = apps;
        });
      } else {
        setState(() => _applications = []);
      }
    } catch (err) {
      setState(() {
        _error = err.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitRequest() async {
    if (_isGuest) {
      await NotificationHelper.showWarning(
        context,
        'Guests cannot request partner access. Please create a full account.',
      );
      return;
    }
    if (_selectedOwner == null) {
      await NotificationHelper.showWarning(
        context,
        'Select a user to request access.',
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _api.submitRequest(
        ownerId: _selectedOwner!.id,
        module: _selectedModule,
      );
      _ownerSearchController.clear();
      setState(() {
        _selectedOwner = null;
        _ownerSuggestions = [];
      });
      await NotificationHelper.showSuccess(
        context,
        'Request sent! We will notify you once it is approved.',
      );
      await _loadData();
    } catch (err) {
      await NotificationHelper.showError(
        context,
        err.toString(),
        title: 'Unable to send request',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _onOwnerSearchChanged(String value) {
    _ownerSearchDebounce?.cancel();
    _ownerSearchDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      if (_userEmail.isEmpty) return;
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        setState(() {
          _ownerSuggestions = [];
          _selectedOwner = null;
        });
        return;
      }
      final results = await _api.searchOwners(trimmed);
      if (!mounted) return;
      setState(() {
        _ownerSuggestions = results;
      });
    });
  }

  void _selectOwnerSuggestion(PartnerOwnerSuggestion suggestion) {
    setState(() {
      _selectedOwner = suggestion;
      _ownerSearchController.text = suggestion.email;
    });
  }

  Future<void> _updatePreference(bool allow) async {
    if (_isGuest) {
      await NotificationHelper.showWarning(
        context,
        'Guests cannot modify partner preferences.',
      );
      return;
    }
    setState(() => _preference = allow);
    try {
      await _api.updatePreference(allowRequests: allow);
      await context.read<AuthState>().togglePartnerRequests(allow);
    } catch (err) {
      setState(() => _preference = !allow);
      await NotificationHelper.showError(
        context,
        '$err\nWe kept your previous preference. Please retry later.',
      );
    }
  }

  Future<void> _respondToRequest(
    PartnerAccessEntry entry,
    String status,
  ) async {
    try {
      await _api.decideRequest(
        entryId: entry.id,
        status: status,
      );
      await _loadData();
    } catch (err) {
      await NotificationHelper.showError(
        context,
        err.toString(),
        title: 'Request update failed',
      );
    }
  }

  Future<void> _viewSharedLogs(PartnerAccessEntry entry) async {
    try {
      final ownerId = entry.ownerId ?? entry.partnerId;
      if (ownerId == null) {
        await NotificationHelper.showWarning(
          context,
          'This assignment is missing an owner reference.',
        );
        return;
      }
      final logs = await _api.fetchSharedLogs(ownerId: ownerId);
      if (!mounted) return;
      if (logs.isEmpty) {
        await NotificationHelper.showWarning(
          context,
          '${entry.ownerName} has not shared any partner-visible entries yet. '
          'Ask them to mark logs as "Shared with partner" when creating them.',
        );
        return;
      }
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          builder: (context, controller) => ListView.builder(
            controller: controller,
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryPurple.withOpacity(0.15),
                  child: Text(
                    log.sugarGrams.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(log.productName),
                subtitle: Text(
                  '${log.date.toLocal().toString().split(' ').first} - ${log.emotion}',
                ),
              );
            },
          ),
        ),
      );
    } catch (err) {
      await NotificationHelper.showError(
        context,
        err.toString(),
        title: 'Unable to fetch shared logs',
      );
    }
  }

  void _openPartnerAnalytics(PartnerAccessEntry entry) {
    if (entry.ownerId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalyticsPage(
          logs: const [],
          initialOwnerId: entry.ownerId,
          initialOwnerName: entry.ownerName,
          embedInNavigation: false,
        ),
      ),
    );
  }

  Future<void> _submitApplication() async {
    if (_isGuest) {
      await NotificationHelper.showWarning(
        context,
        'Guests cannot apply for partner tools. Please create a full account.',
      );
      return;
    }
    final expertise = _expertiseController.text.trim();
    final motivation = _motivationController.text.trim();
    if (expertise.isEmpty || motivation.isEmpty) {
      await NotificationHelper.showWarning(
        context,
        'Please share both your expertise and motivation so we can review the request.',
      );
      return;
    }
    
    setState(() => _isApplying = true);
    
    try {
      // Try to submit online
      await _api.applyForPartnerRole(
        expertise: expertise,
        motivation: motivation,
      );
      
      setState(() => _applicationStatus = 'PENDING');
      await NotificationHelper.showSuccess(
        context,
        'Application submitted! We\'ll notify you when it is reviewed.',
      );
    } catch (err) {
      // Check if this is a network error (offline mode)
      final errorString = err.toString().toLowerCase();
      final isNetworkError = errorString.contains('network') || 
                            errorString.contains('connection') || 
                            errorString.contains('offline') ||
                            errorString.contains('socketexception') ||
                            errorString.contains('failed host lookup');
      
      if (isNetworkError) {
        // Show offline error
        await NotificationHelper.showWarning(
          context,
          'You\'re offline. Please connect to the internet to submit your partner application.',
          title: 'No Internet Connection',
        );
      } else {
        // Some other server error
        await NotificationHelper.showWarning(
          context,
          err.toString(),
          title: 'Unable to submit application',
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  Future<void> _reviewApplication(
    PartnerApplicationRecord record,
    String status,
  ) async {
    try {
      await _api.reviewApplication(
        applicationId: record.id,
        status: status,
      );
      if (!mounted) return;
      await _loadData();
      await NotificationHelper.showSuccess(
        context,
        status == 'APPROVED'
            ? 'Application approved. The user can now act as a partner.'
            : 'Application rejected.',
      );
    } catch (err) {
      await NotificationHelper.showError(
        context,
        err.toString(),
        title: 'Unable to update application',
      );
    }
  }

  void _showAddSugarLogDialog() {
    showDialog(
      context: context,
      builder: (_) => SugarLogCreationDialog(
        onCreated: (_) {},
      ),
    );
  }

  Widget _buildBottomNavigation({required bool canLogSugar}) {
    const tabs = [
      _PartnerNavItem(label: 'Home', icon: Icons.home, index: 0),
      _PartnerNavItem(label: 'Analytics', icon: Icons.bar_chart, index: 1),
      _PartnerNavItem(label: 'Community', icon: Icons.emoji_events, index: 2),
      _PartnerNavItem(label: 'Profile', icon: Icons.person, index: 3),
    ];

    final notchIndex = canLogSugar ? (tabs.length / 2).floor() : null;
    final navChildren = <Widget>[];

    for (var i = 0; i < tabs.length; i++) {
      if (notchIndex != null && i == notchIndex) {
        navChildren.add(const SizedBox(width: 48));
      }
      final tab = tabs[i];
      final isActive = tab.index == 3;
      final color =
          isActive ? Theme.of(context).colorScheme.primary : Colors.grey;
      navChildren.add(
        Expanded(
          child: MaterialButton(
            minWidth: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            onPressed: () => _handleNavSelection(tab.index),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tab.icon, size: 22, color: color),
                const SizedBox(height: 2),
                Text(
                  tab.label,
                  style: TextStyle(fontSize: 11, color: color),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BottomAppBar(
      shape: canLogSugar ? const CircularNotchedRectangle() : null,
      notchMargin: canLogSugar ? 8 : 0,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: navChildren,
      ),
    );
  }

  void _handleNavSelection(int index) {
    if (index == 3 && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.mainNav,
      (route) => false,
      arguments: MainNavArguments(initialIndex: index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    _role = authState.currentUser?.role ?? _role;
    final canLogSugar = authState.featureFlags.contains('sugar_logs');
    final bool showNavigation = _role.toUpperCase() != 'ADMIN';

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroBanner(authState),
            const SizedBox(height: 16),
            if (_error != null) _buildErrorBanner(),
            if (_isLoading)
              const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_isGuest) _buildGuestNotice(),
              if (!_isGuest)
                _sectionCard(
                  title: 'Network pulse',
                  subtitle:
                      'Requests, shares, and active collaborations at a glance.',
                  icon: Icons.auto_graph_rounded,
                  child: _buildHeroStats(),
                ),
              if (!_isGuest)
                _sectionCard(
                  title: 'Collaboration summary',
                  subtitle:
                      'Who has access, what you shared, and how your requests are progressing.',
                  icon: Icons.dashboard_customize_outlined,
                  child: _buildCollaborationSummary(),
                ),
              if (_role == 'ADMIN') _buildApplicationQueue(),
              if (_role == 'USER' && !_isGuest) _buildPartnerApplicationCard(),
              if (_role == 'USER' && !_isGuest) _buildPreferenceCard(),
              if (_role == 'PARTNER') _buildRequestForm(),
              if (_role == 'USER') _buildIncomingSection(),
              if (_role == 'PARTNER') _buildOutgoingSection(),
              _buildAssignmentSection(_role),
            ],
          ],
        ),
      ),
    );

    final body = RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceLG,
        ),
        children: [content],
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      floatingActionButton: showNavigation && canLogSugar
          ? FloatingActionButton(
              onPressed: _showAddSugarLogDialog,
              tooltip: 'Register Sugar Intake',
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: showNavigation && canLogSugar
          ? FloatingActionButtonLocation.centerDocked
          : null,
      bottomNavigationBar: showNavigation
          ? _buildBottomNavigation(canLogSugar: canLogSugar)
          : null,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryPurple.withOpacity(0.08),
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryPurple.withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentTeal.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(child: body),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(AuthState authState) {
    final displayName = _userName.isEmpty
        ? authState.currentUser?.fullName ?? 'Partner'
        : _userName;
    final email =
        _userEmail.isEmpty ? authState.currentUser?.email ?? '' : _userEmail;
    final badgeColor = _role.toUpperCase() == 'PARTNER'
        ? AppTheme.accentTeal
        : AppTheme.infoBlue;
    final status =
        (_applicationStatus ?? (_role == 'PARTNER' ? 'APPROVED' : 'DRAFT'))
            .toUpperCase();
    final statusColor = status == 'APPROVED'
        ? AppTheme.successGreen
        : status == 'PENDING'
            ? AppTheme.warningOrange
            : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLG,
        vertical: AppTheme.spaceLG,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF51219C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: AppTheme.shadowLevel3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  displayName.isEmpty ? '?' : displayName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(color: Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ],
                ),
              ),
              if (_role != 'ADMIN')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                    vertical: AppTheme.spaceXS,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.waving_hand_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Care network hub',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Wrap(
            spacing: AppTheme.spaceSM,
            runSpacing: AppTheme.spaceSM,
            children: [
              _StatusChip(
                label: _role.toUpperCase(),
                color: badgeColor,
                icon: Icons.verified_user_outlined,
              ),
              _StatusChip(
                label: status,
                color: statusColor,
                icon: Icons.flag_outlined,
              ),
              _StatusChip(
                label: _preference ? 'Requests enabled' : 'Requests paused',
                color: _preference ? AppTheme.successGreen : AppTheme.errorRed,
                icon: Icons.sync_alt_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          const Text(
            'Control how partners collaborate with you and keep everyone aligned.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return GustCard(
      backgroundColor: AppTheme.errorRed.withOpacity(0.08),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: Text(
              _error ?? '',
              style: const TextStyle(
                color: AppTheme.errorRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestNotice() {
    return GustCard(
      backgroundColor: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Partner tools unavailable',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppTheme.spaceXS),
                Text(
                  'Guests can browse the app but must create an account to invite or approve partners.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStats() {
    final pendingApprovals =
        _incoming.where((entry) => entry.status == 'PENDING').length;
    final activePartnerships =
        _assignments.where((entry) => entry.status == 'APPROVED').length;
    final outgoingPending =
        _outgoing.where((entry) => entry.status == 'PENDING').length;
    final stats = [
      _StatCardConfig(
        label: 'Pending approvals',
        value: '$pendingApprovals',
        icon: Icons.inbox_rounded,
        colors: const [Color(0xFF8E24AA), Color(0xFF651FFF)],
      ),
      _StatCardConfig(
        label: 'Active shares',
        value: '$activePartnerships',
        icon: Icons.handshake_rounded,
        colors: const [Color(0xFF26A69A), Color(0xFF43A047)],
      ),
      _StatCardConfig(
        label: 'Your requests',
        value: '$outgoingPending',
        icon: Icons.outbox_outlined,
        colors: const [Color(0xFF5C6BC0), Color(0xFF3949AB)],
      ),
    ];

    final availableWidth =
        MediaQuery.of(context).size.width - (AppTheme.spaceLG * 2);
    const spacing = AppTheme.spaceMD;
    final isCompact = availableWidth < 640;
    final tileWidth = isCompact
        ? double.infinity
        : (availableWidth - spacing * (stats.length - 1)) / stats.length;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: stats
          .map(
            (config) => SizedBox(
              width: isCompact ? double.infinity : tileWidth,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spaceLG,
                  horizontal: AppTheme.spaceLG,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: config.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  boxShadow: [
                    BoxShadow(
                      color: config.colors.last.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _buildHeroStat(
                  label: config.label,
                  value: config.value,
                  icon: config.icon,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCollaborationSummary() {
    final pendingApprovals =
        _incoming.where((entry) => entry.status == 'PENDING').length;
    final outgoingApproved =
        _outgoing.where((entry) => entry.status == 'APPROVED').length;
    final outgoingPending =
        _outgoing.where((entry) => entry.status == 'PENDING').length;
    final outgoingRejected =
        _outgoing.where((entry) => entry.status == 'REJECTED').length;
    final modules =
        _assignments.map((entry) => _friendlyModule(entry.module)).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInsightRowCompact(
          icon: Icons.hourglass_top_outlined,
          color: AppTheme.warningOrange,
          label: 'Pending approvals',
          value: pendingApprovals.toString(),
          subtitle: pendingApprovals == 0
              ? 'You are up to date – no approvals waiting.'
              : '$pendingApprovals request${pendingApprovals > 1 ? 's' : ''} waiting for your response.',
        ),
        const SizedBox(height: AppTheme.spaceSM),
        _buildInsightRowCompact(
          icon: Icons.outbox_rounded,
          color: AppTheme.infoBlue,
          label: 'Your requests',
          value: '$outgoingApproved approved / $outgoingPending pending',
          subtitle: outgoingRejected > 0
              ? '$outgoingRejected request${outgoingRejected > 1 ? 's were' : ' was'} rejected. You can resend after updating context.'
              : 'Keep an eye on approvals to unlock shared dashboards.',
        ),
        const SizedBox(height: AppTheme.spaceSM),
        _buildInsightRowCompact(
          icon: Icons.handshake_outlined,
          color: AppTheme.successGreen,
          label: 'Active partnerships',
          value: _assignments.length.toString(),
          subtitle: modules.isEmpty
              ? 'No shared modules yet.'
              : 'Sharing across ${modules.length} module${modules.length == 1 ? '' : 's'}.',
        ),
        if (modules.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spaceSM),
          Wrap(
            spacing: AppTheme.spaceSM,
            runSpacing: AppTheme.spaceXS,
            children: modules
                .map(
                  (module) => Chip(
                    label: Text(module),
                    backgroundColor: AppTheme.backgroundGrey,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildApplicationQueue() {
    if (_applications.isEmpty) {
      return _buildEmptyState(
        'No partner applications',
        'Users will appear here once they submit a partner request.',
      );
    }
    return _buildSection(
      title: 'Partner applications',
      subtitle: 'Review and respond to new coach or caregiver applications.',
      icon: Icons.volunteer_activism_outlined,
      accent: AppTheme.accentCoral,
      child: Column(
        children: _applications
            .map(
              (record) => GustCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          record.submittedAt
                              .toLocal()
                              .toString()
                              .split(' ')
                              .first,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.email,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text('Expertise: ${record.expertise}'),
                    const SizedBox(height: 4),
                    Text('Motivation: ${record.motivation}'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _reviewApplication(record, 'REJECTED'),
                          icon:
                              const Icon(Icons.close, color: AppTheme.errorRed),
                          label: const Text('Reject'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _reviewApplication(record, 'APPROVED'),
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successGreen,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPartnerApplicationCard() {
    final status = _applicationStatus;
    return GustCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceLG),
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.favorite_outline,
                    color: AppTheme.primaryPurple),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Become a care partner',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Share curated insights with loved ones or coaches. Tell us about your expertise to unlock partner tools.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (status != null)
                Chip(
                  backgroundColor: status == 'APPROVED'
                      ? AppTheme.successGreen.withOpacity(0.15)
                      : Colors.amber.withOpacity(0.15),
                  label: Text(
                    status == 'APPROVED'
                        ? 'Approved'
                        : status == 'PENDING'
                            ? 'Pending review'
                            : 'Pending (offline)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFilledField(
            controller: _expertiseController,
            label: 'Your role or expertise',
            hint: 'e.g. Nutritionist, Parent, Coach',
          ),
          const SizedBox(height: AppTheme.spaceSM),
          _buildFilledField(
            controller: _motivationController,
            label: 'Motivation',
            hint: 'Tell us how you plan to support the user.',
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isApplying ? null : _submitApplication,
              icon: _isApplying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.volunteer_activism),
              label: Text(status == null ? 'Submit application' : 'Update'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceLG,
                  vertical: AppTheme.spaceSM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilledField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppTheme.backgroundGrey.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 2),
        ),
      ),
    );
  }

  Widget _buildPreferenceCard() {
    return GustCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceLG),
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      gradient: const LinearGradient(
        colors: [Color(0xFFF8F4FF), Colors.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _preference
                  ? Icons.toggle_on_outlined
                  : Icons.toggle_off_outlined,
              color: AppTheme.primaryPurple,
              size: 32,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allow partner requests',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Trusted partners can request access to curated parts of your dashboard. Disable when you need privacy.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _preference,
            onChanged: _updatePreference,
            activeColor: AppTheme.primaryPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestForm() {
    return GustCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceLG),
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.infoBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.swap_horiz_outlined,
                    color: AppTheme.infoBlue),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request access',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Invite someone to share their dashboard or analytics view. Search for them by name or email.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          TextField(
            controller: _ownerSearchController,
            onChanged: _onOwnerSearchChanged,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Search by name or email',
              hintText: 'friend@email.com',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppTheme.backgroundGrey.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _ownerSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _ownerSearchController.clear();
                        _onOwnerSearchChanged('');
                        setState(() => _selectedOwner = null);
                      },
                    ),
            ),
          ),
          if (_selectedOwner != null) ...[
            const SizedBox(height: AppTheme.spaceSM),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceXS,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.accentTeal),
                  const SizedBox(width: AppTheme.spaceXS),
                  Text(
                    _selectedOwner!.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedOwner = null),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
          ],
          if (_ownerSuggestions.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              'Tap to choose a collaborator',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spaceXS),
            Wrap(
              spacing: AppTheme.spaceSM,
              runSpacing: AppTheme.spaceXS,
              children: _ownerSuggestions.map<Widget>((suggestion) {
                final bool selected = _selectedOwner?.id == suggestion.id;
                return ChoiceChip(
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        suggestion.email,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  selected: selected,
                  onSelected: (_) => _selectOwnerSuggestion(suggestion),
                  selectedColor: AppTheme.primaryPurple.withOpacity(0.2),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: AppTheme.spaceSM),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            decoration: BoxDecoration(
              color: AppTheme.backgroundGrey.withOpacity(0.6),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bar_chart, color: AppTheme.primaryPurple),
                SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analytics access',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Partners can explore daily logs, dashboards, and trends once this single request is approved.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitRequest,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Send request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceLG,
                  vertical: AppTheme.spaceSM,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingSection() {
    final pending =
        _incoming.where((entry) => entry.status == 'PENDING').toList();
    if (pending.isEmpty) {
      return _buildEmptyState(
        'No pending approvals',
        'Partner requests that need your confirmation will show up here.',
      );
    }

    return _buildSection(
      title: 'Pending approvals',
      subtitle: 'Approve or decline partner access requests waiting on you.',
      icon: Icons.mark_email_unread_outlined,
      accent: AppTheme.warningOrange,
      child: Column(
        children: pending
            .map(
              (entry) => _buildEntryTile(
                icon: Icons.mail_rounded,
                color: AppTheme.warningOrange,
                title: entry.partnerName,
                subtitle: '${_friendlyModule(entry.module)} - ${entry.status}',
                trailing: Wrap(
                  spacing: AppTheme.spaceSM,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      onPressed: () => _respondToRequest(entry, 'REJECTED'),
                      tooltip: 'Reject',
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _respondToRequest(entry, 'APPROVED'),
                      tooltip: 'Approve',
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildOutgoingSection() {
    if (_outgoing.isEmpty) {
      return _buildEmptyState(
        'No outgoing requests',
        'Submit a request to collaborate with a user.',
      );
    }
    return _buildSection(
      title: 'Your requests',
      subtitle: 'Track collaboration invites you have sent to others.',
      icon: Icons.send_outlined,
      accent: AppTheme.infoBlue,
      child: Column(
        children: _outgoing
            .map(
              (entry) => _buildEntryTile(
                icon: Icons.outbox_rounded,
                color: AppTheme.infoBlue,
                title: entry.ownerName,
                subtitle: '${_friendlyModule(entry.module)} - ${entry.status}',
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildAssignmentSection(String role) {
    if (_assignments.isEmpty) {
      return _buildEmptyState(
        'No active partnerships',
        'Approved collaborations will show up here.',
      );
    }
    return _buildSection(
      title: 'Active partnerships',
      subtitle: 'Approved collaborations currently sharing data.',
      icon: Icons.handshake_outlined,
      accent: AppTheme.successGreen,
      child: Column(
        children: _assignments.map(
          (entry) {
            final isPartner = role == 'PARTNER';
            Widget? trailing;
            if (isPartner && entry.status == 'APPROVED') {
              if (entry.module == 'SUGAR_LOGS') {
                trailing = TextButton(
                  onPressed: () => _viewSharedLogs(entry),
                  child: const Text('View logs'),
                );
              } else if (entry.module == 'ANALYTICS') {
                trailing = TextButton(
                  onPressed: () => _openPartnerAnalytics(entry),
                  child: const Text('View analytics'),
                );
              }
            }

            return _buildEntryTile(
              icon: Icons.handshake_rounded,
              color: AppTheme.successGreen,
              title: isPartner ? entry.ownerName : entry.partnerName,
              subtitle: '${_friendlyModule(entry.module)} - ${entry.status}',
              trailing: trailing,
            );
          },
        ).toList(),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    IconData? icon,
    String? subtitle,
    Color? accent,
  }) {
    final Color chipColor = accent ?? AppTheme.primaryPurple;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            chipColor.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: chipColor.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: chipColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          chipColor,
                          chipColor.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: chipColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                if (icon != null) const SizedBox(width: AppTheme.spaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF2D1B47),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: chipColor.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMD),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.infoBlue.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppTheme.infoBlue.withOpacity(0.15),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.infoBlue.withOpacity(0.15),
                  AppTheme.infoBlue.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.infoBlue.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: AppTheme.infoBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D1B47),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXS),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceSM,
        ),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.15),
                  color.withOpacity(0.08),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF2D1B47),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          trailing: trailing,
        ),
      ),
    );
  }

  Widget _buildHeroStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.15),
                color.withOpacity(0.08),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: AppTheme.spaceMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF2D1B47),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightRowCompact({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.15),
                color.withOpacity(0.08),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: AppTheme.spaceMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF2D1B47),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _friendlyModule(String module) {
    switch (module) {
      case 'ANALYTICS':
        return 'Analytics';
      case 'DASHBOARD':
        return 'Dashboard';
      default:
        return 'Daily logbook';
    }
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.primaryPurple.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppTheme.primaryPurple.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6A1B9A),
                        Color(0xFF8E24AA),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryPurple.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: AppTheme.spaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF2D1B47),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMD),
            child,
          ],
        ),
      ),
    );
  }
}

class _PartnerNavItem {
  final String label;
  final IconData icon;
  final int index;
  const _PartnerNavItem({
    required this.label,
    required this.icon,
    required this.index,
  });
}

class _StatCardConfig {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> colors;
  const _StatCardConfig({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
  });
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceXS,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppTheme.spaceXS),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
