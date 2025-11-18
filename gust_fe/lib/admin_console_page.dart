import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/admin_api.dart';
import 'state/auth_state.dart';
import 'theme/app_theme.dart';
import 'utils/notification_helper.dart';
import 'widgets/gust_card.dart';
import 'main.dart';
import 'services/partner_access_api.dart';

class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({super.key});

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  final AdminApi _api = AdminApi();
  AdminInsights? _insights;
  List<AdminUser> _users = [];
  List<PartnerApplicationRecord> _applications = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'ALL';
  int _currentPage = 0;
  static const int _pageSize = 6;
  static const Map<String, String> _roleFilterLabels = {
    'ALL': 'All roles',
    'USER': 'Users',
    'PARTNER': 'Partners',
    'ADMIN': 'Admins',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authState = context.read<AuthState>();
    if ((authState.currentUser?.role ?? '').toUpperCase() != 'ADMIN') {
      setState(() {
        _error = 'You need admin privileges to view this dashboard.';
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final insights = await _api.fetchInsights();
      final users = await _api.fetchUsers();
      final apps = await _api.fetchApplications();
      setState(() {
        _insights = insights;
        _users = users;
        _applications = apps;
        _error = null;
        _currentPage = 0;
      });
    } catch (err) {
      setState(() {
        _error = err.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateRole(AdminUser user, String role) async {
    try {
      final updated = await _api.updateRole(userId: user.id, role: role);
      setState(() {
        final index = _users.indexWhere((element) => element.id == user.id);
        if (index >= 0) {
          _users[index] = updated;
        }
      });
    } catch (err) {
      await NotificationHelper.showError(
        context,
        err.toString(),
        title: 'Unable to update role',
      );
    }
  }

  Future<void> _logout() async {
    final authState = context.read<AuthState>();
    await authState.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  Widget _buildHeader(AuthState authState) {
    final name = authState.currentUser?.fullName ?? 'Admin';
    return Container(
      padding: EdgeInsets.all(AppTheme.spaceLG),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryPurple, Color(0xFF512DA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: AppTheme.shadowLevel3,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(120),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 12,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admin Command Center',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Welcome back, $name',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceLG),
              Wrap(
                spacing: AppTheme.spaceSM,
                runSpacing: AppTheme.spaceSM,
                children: const [
                  _HeroChip(
                    icon: Icons.shield_moon_outlined,
                    label: 'Security overview',
                  ),
                  _HeroChip(
                    icon: Icons.flash_on_rounded,
                    label: 'Live insights',
                  ),
                  _HeroChip(
                    icon: Icons.people_outline,
                    label: 'Community health',
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceSM),
              const Text(
                'Monitor usage, promote power users, and keep the community healthy.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return GustCard(
      backgroundColor: AppTheme.errorRed.withOpacity(0.08),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed),
          SizedBox(width: AppTheme.spaceSM),
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

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: EdgeInsets.all(AppTheme.spaceLG),
            children: [
              _buildHeader(authState),
              SizedBox(height: AppTheme.spaceLG),
              if (_error != null) _buildErrorBanner(),
              if (_insights != null) ...[
                _buildInsightsGrid(_insights!),
                SizedBox(height: AppTheme.spaceLG),
              ],
              _buildPartnerShowcase(),
              if (_applications.isNotEmpty) ...[
                SizedBox(height: AppTheme.spaceLG),
                _buildApplicationsCard(),
              ],
              SizedBox(height: AppTheme.spaceLG),
              _buildUserTable(),
            ],
          );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryPurple.withOpacity(0.08),
            Colors.white,
            Colors.white,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: body,
        ),
      ),
    );
  }

  Widget _buildInsightsGrid(AdminInsights insights) {
    final cards = [
      _MetricCard(
        label: 'Total users',
        value: insights.totalUsers.toString(),
        icon: Icons.people_outline,
      ),
      _MetricCard(
        label: 'Admins',
        value: insights.adminCount.toString(),
        icon: Icons.verified_user_outlined,
      ),
      _MetricCard(
        label: 'Partners',
        value: insights.partnerCount.toString(),
        icon: Icons.handshake_outlined,
      ),
      _MetricCard(
        label: 'Pending requests',
        value: insights.pendingPartnerRequests.toString(),
        icon: Icons.inbox_outlined,
      ),
      _MetricCard(
        label: 'Logs synced',
        value: insights.sugarLogCount.toString(),
        icon: Icons.analytics_outlined,
      ),
      _MetricCard(
        label: 'Avg grams/day',
        value: insights.averageDailySugar.toStringAsFixed(1),
        icon: Icons.bubble_chart_outlined,
      ),
    ];

    return Wrap(
      spacing: AppTheme.spaceMD,
      runSpacing: AppTheme.spaceMD,
      children: cards,
    );
  }

  Widget _buildPartnerShowcase() {
    final partners = _users
        .where((user) => user.role.toUpperCase() == 'PARTNER')
        .toList();
    return GustCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake, color: AppTheme.primaryPurple),
              SizedBox(width: AppTheme.spaceSM),
              Text(
                'Active partners',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMD,
                  vertical: AppTheme.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Text(
                  partners.isEmpty
                      ? 'No partners yet'
                      : '${partners.length} partner${partners.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: AppTheme.accentTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spaceXS),
          Text(
            'Approved collaborators show up here for quick context.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          SizedBox(height: AppTheme.spaceMD),
          if (partners.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppTheme.spaceMD),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1,
                      color: AppTheme.textSecondary),
                  SizedBox(width: AppTheme.spaceMD),
                  Expanded(
                    child: Text(
                      'Approve pending partner applications to start building your care network.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: AppTheme.spaceMD,
              runSpacing: AppTheme.spaceMD,
              children: partners.map(_buildPartnerBadge).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPartnerBadge(AdminUser user) {
    final accent = _roleAccentColor('PARTNER');
    final initials =
        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'P';
    final parsedJoinDate =
        user.createdAt == null ? null : DateTime.tryParse(user.createdAt!);
    final joinedDate = parsedJoinDate == null
        ? null
        : parsedJoinDate.toLocal().toString().split(' ').first;
    return Container(
      width: 260,
      padding: EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                foregroundColor: accent,
                child: Text(initials),
              ),
              SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName.isEmpty ? 'Partner' : user.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      user.email,
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
          SizedBox(height: AppTheme.spaceSM),
          Row(
            children: [
              const Icon(Icons.badge, size: 16, color: AppTheme.textSecondary),
              SizedBox(width: AppTheme.spaceXS),
              Text(
                user.allowPartnerRequests ? 'Accepting requests' : 'Closed to requests',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
          if (joinedDate != null) ...[
            SizedBox(height: AppTheme.spaceXS),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 16, color: AppTheme.textSecondary),
                SizedBox(width: AppTheme.spaceXS),
                Text(
                  'Since $joinedDate',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserTable() {
    final filtered = _getFilteredUsers();
    final totalRecords = filtered.length;
    final totalPages =
        totalRecords == 0 ? 1 : ((totalRecords - 1) ~/ _pageSize) + 1;
    final clampedPage =
        totalRecords == 0 ? 0 : _currentPage.clamp(0, totalPages - 1);

    if (clampedPage != _currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentPage = clampedPage);
        }
      });
    }

    final startIndex = totalRecords == 0 ? 0 : clampedPage * _pageSize;
    var endIndex = totalRecords == 0 ? 0 : startIndex + _pageSize;
    if (endIndex > totalRecords) endIndex = totalRecords;
    final visibleUsers = totalRecords == 0
        ? <AdminUser>[]
        : filtered.sublist(startIndex, endIndex);

    final filtersActive =
        _roleFilter != 'ALL' || _searchQuery.trim().isNotEmpty;

    return GustCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage roles',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search, filter, and promote members without leaving this page.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMD,
                  vertical: AppTheme.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Text(
                  '${filtered.length} of ${_users.length} profiles',
                  style: TextStyle(
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (filtersActive)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Clear filters'),
              ),
            ),
          SizedBox(height: AppTheme.spaceSM),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search by name or email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
            ),
          ),
          SizedBox(height: AppTheme.spaceSM),
          _buildRoleFilters(),
          SizedBox(height: AppTheme.spaceMD),
          if (visibleUsers.isEmpty)
            _buildFilteredEmptyState()
          else
            Column(
              children: visibleUsers.map(_buildUserRow).toList(),
            ),
          SizedBox(height: AppTheme.spaceMD),
          _buildPaginationControls(
            totalRecords: totalRecords,
            totalPages: totalPages,
            currentPage: clampedPage,
            startIndex: startIndex,
            endIndex: endIndex,
          ),
        ],
      ),
    );
  }

  List<AdminUser> _getFilteredUsers() {
    final query = _searchQuery.toLowerCase();
    return _users.where((user) {
      final matchesRole =
          _roleFilter == 'ALL' || user.role.toUpperCase() == _roleFilter;
      final matchesQuery = query.isEmpty ||
          user.fullName.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
      return matchesRole && matchesQuery;
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim();
      _currentPage = 0;
    });
  }

  void _resetFilters() {
    setState(() {
      _roleFilter = 'ALL';
      _searchQuery = '';
      _currentPage = 0;
      _searchController.clear();
    });
  }

  Widget _buildRoleFilters() {
    return Wrap(
      spacing: AppTheme.spaceSM,
      runSpacing: AppTheme.spaceSM,
      children: _roleFilterLabels.entries.map((entry) {
        final isSelected = _roleFilter == entry.key;
        return ChoiceChip(
          label: Text(entry.value),
          selected: isSelected,
          onSelected: (_) {
            if (!isSelected) {
              setState(() {
                _roleFilter = entry.key;
                _currentPage = 0;
              });
            }
          },
          selectedColor: AppTheme.primaryPurple.withOpacity(0.15),
          labelStyle: TextStyle(
            color: isSelected ? AppTheme.primaryPurple : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFilteredEmptyState() {
    final hasUsers = _users.isNotEmpty;
    final message = hasUsers
        ? 'No users match your filters. Try adjusting the search keywords or role chips above.'
        : 'No users have been synced yet. New sign-ups will automatically appear here.';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_off, color: AppTheme.textSecondary),
          SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(AdminUser user) {
    final initials =
        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?';
    final accent = _roleAccentColor(user.role);
    final parsedJoinDate =
        user.createdAt == null ? null : DateTime.tryParse(user.createdAt!);
    final joinedDate = parsedJoinDate == null
        ? null
        : parsedJoinDate.toLocal().toString().split(' ').first;

    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spaceSM),
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.dividerGrey.withOpacity(0.3)),
        boxShadow: AppTheme.shadowLevel1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: accent.withOpacity(0.15),
            foregroundColor: accent,
            child: Text(initials),
          ),
          SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.fullName.isEmpty ? 'Unknown user' : user.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceSM,
                        vertical: AppTheme.spaceXS,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      child: Text(
                        user.role,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
                if (joinedDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Joined $joinedDate',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: AppTheme.spaceMD),
          DropdownButtonHideUnderline(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSM,
                vertical: AppTheme.spaceXS,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.dividerGrey.withOpacity(0.6)),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: DropdownButton<String>(
                value: user.role,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: const [
                  DropdownMenuItem(value: 'USER', child: Text('User')),
                  DropdownMenuItem(value: 'PARTNER', child: Text('Partner')),
                  DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                ],
                onChanged: (value) {
                  if (value != null && value != user.role) {
                    _updateRole(user, value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls({
    required int totalRecords,
    required int totalPages,
    required int currentPage,
    required int startIndex,
    required int endIndex,
  }) {
    final hasPrev = totalRecords > 0 && currentPage > 0;
    final hasNext = totalRecords > 0 && currentPage < totalPages - 1;
    final summary = totalRecords == 0
        ? 'No users to display'
        : 'Showing ${startIndex + 1}–$endIndex of $totalRecords users';
    final displayPage = totalRecords == 0 ? 1 : currentPage + 1;

    return Row(
      children: [
        Text(
          summary,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.textSecondary),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: hasPrev
              ? () => setState(() => _currentPage = currentPage - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Prev'),
        ),
        SizedBox(width: AppTheme.spaceSM),
        Text(
          '$displayPage / $totalPages',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        SizedBox(width: AppTheme.spaceSM),
        OutlinedButton.icon(
          onPressed: hasNext
              ? () => setState(() => _currentPage = currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ),
      ],
    );
  }

  Color _roleAccentColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return AppTheme.primaryPurple;
      case 'PARTNER':
        return AppTheme.accentTeal;
      default:
        return AppTheme.infoBlue;
    }
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return GustCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.textSecondary),
          SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: AppTheme.spaceXS),
                Text(
                  subtitle,
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

  Widget _buildApplicationsCard() {
    return GustCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mail_outline, color: AppTheme.primaryPurple),
              SizedBox(width: AppTheme.spaceSM),
              Text(
                'Partner applications',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          SizedBox(height: AppTheme.spaceSM),
          ..._applications.map(_buildApplicationTile),
        ],
      ),
    );
  }

  Widget _buildApplicationTile(PartnerApplicationRecord record) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.email,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                record.submittedAt.toLocal().toString().split(' ').first,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Expertise: ${record.expertise}'),
          const SizedBox(height: 4),
          Text('Motivation: ${record.motivation}'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _handleApplication(record, 'REJECTED'),
                icon: const Icon(Icons.close, color: AppTheme.errorRed),
                label: const Text('Reject'),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              ElevatedButton.icon(
                onPressed: () => _handleApplication(record, 'APPROVED'),
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
    );
  }

  void _updateUserRoleLocally(String email, String role) {
    final index = _users.indexWhere(
      (user) => user.email.toLowerCase() == email.toLowerCase(),
    );
    if (index == -1) return;
    _users[index] = _users[index].copyWith(role: role);
  }

  Future<void> _handleApplication(
    PartnerApplicationRecord record,
    String status,
  ) async {
    try {
      await _api.reviewApplication(record: record, status: status);
      setState(() {
        _applications =
            _applications.where((app) => app.email != record.email).toList();
        if (status == 'APPROVED') {
          _updateUserRoleLocally(record.email, 'PARTNER');
        }
      });
      await _loadData();
      if (!mounted) return;
      await NotificationHelper.showSuccess(
        context,
        status == 'APPROVED'
            ? 'Application approved.'
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
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: GustCard(
        padding: EdgeInsets.all(AppTheme.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            SizedBox(height: AppTheme.spaceSM),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceXS,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          SizedBox(width: AppTheme.spaceXS),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
