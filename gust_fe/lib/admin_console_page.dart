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
  final AdminApi _api = const AdminApi();
  AdminInsights? _insights;
  List<AdminUser> _users = [];
  List<PartnerApplicationRecord> _applications = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'ALL';
  int _currentPage = 0;
  static const int _pageSize = 10; // Increased page size for better scrolling
  static const Map<String, String> _roleFilterLabels = {
    'ALL': 'All',
    'USER': 'Users',
    'PARTNER': 'Partners',
    'ADMIN': 'Admins',
    'ANONYMOUS': 'Guest',
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
      await NotificationHelper.showSuccess(context, 'Role updated to $role');
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

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(authState),
          if (_error != null) _buildSliverError(),
          if (_insights != null) ...[
            const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spaceMD)),
            _buildSliverInsights(_insights!),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spaceLG)),
          _buildSliverPartnerShowcase(),
          if (_applications.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spaceLG)),
            _buildSliverApplications(),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spaceLG)),
          _buildSliverUserListHeader(),
          _buildSliverUserList(),
          const SliverToBoxAdapter(child: SizedBox(height: 80)), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(AuthState authState) {
    final name = authState.currentUser?.fullName ?? 'Admin';
    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primaryPurple,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryPurple, Color(0xFF512DA8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin Console',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome back, $name',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 24),
              onPressed: _loadData,
              tooltip: 'Refresh',
              color: Colors.white,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, size: 24),
              onPressed: _logout,
              tooltip: 'Logout',
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverError() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: GustCard(
          backgroundColor: AppTheme.errorRed.withOpacity(0.1),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppTheme.errorRed),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Text(
                  _error ?? 'Unknown error',
                  style: const TextStyle(color: AppTheme.errorRed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverInsights(AdminInsights insights) {
    final metrics = [
      _MetricData('Total Users', insights.totalUsers.toString(), Icons.people),
      _MetricData('Admins', insights.adminCount.toString(), Icons.verified_user),
      _MetricData('Partners', insights.partnerCount.toString(), Icons.handshake),
      _MetricData('Requests', insights.pendingPartnerRequests.toString(), Icons.inbox),
      _MetricData('Logs', insights.sugarLogCount.toString(), Icons.analytics),
      _MetricData('Avg Sugar', '${insights.averageDailySugar.toStringAsFixed(1)}g', Icons.bubble_chart),
    ];

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 110,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
          scrollDirection: Axis.horizontal,
          itemCount: metrics.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppTheme.spaceMD),
          itemBuilder: (context, index) => _MetricCard(data: metrics[index]),
        ),
      ),
    );
  }

  Widget _buildSliverPartnerShowcase() {
    final partners = _users
        .where((user) => user.role.toUpperCase() == 'PARTNER')
        .take(5) // Show only first 5 to avoid clutter
        .toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star_outline, color: AppTheme.primaryPurple),
                const SizedBox(width: 8),
                Text(
                  'Top Partners',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSM),
            if (partners.isEmpty)
              const Text('No partners yet.', style: TextStyle(color: Colors.grey))
            else
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: partners.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppTheme.spaceSM),
                  itemBuilder: (context, index) => _MiniPartnerCard(user: partners[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverApplications() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceSM),
                child: Text(
                  'Pending Applications',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              );
            }
            return _ApplicationCard(
              record: _applications[index - 1],
              onApprove: () => _handleApplication(_applications[index - 1], 'APPROVED'),
              onReject: () => _handleApplication(_applications[index - 1], 'REJECTED'),
            );
          },
          childCount: _applications.length + 1,
        ),
      ),
    );
  }

  Widget _buildSliverUserListHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Management',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _roleFilterLabels.entries.map((entry) {
                  final isSelected = _roleFilter == entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _roleFilter = entry.key;
                          _currentPage = 0;
                        });
                      },
                      checkmarkColor: Colors.white,
                      selectedColor: AppTheme.primaryPurple,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverUserList() {
    final filtered = _getFilteredUsers();
    final totalRecords = filtered.length;
    final totalPages = totalRecords == 0 ? 1 : ((totalRecords - 1) ~/ _pageSize) + 1;
    final clampedPage = totalRecords == 0 ? 0 : _currentPage.clamp(0, totalPages - 1);
    
    // Auto-correct page if out of bounds
    if (clampedPage != _currentPage && mounted) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
         setState(() => _currentPage = clampedPage);
       });
    }

    final startIndex = totalRecords == 0 ? 0 : clampedPage * _pageSize;
    var endIndex = totalRecords == 0 ? 0 : startIndex + _pageSize;
    if (endIndex > totalRecords) endIndex = totalRecords;
    
    final visibleUsers = totalRecords == 0
        ? <AdminUser>[]
        : filtered.sublist(startIndex, endIndex);

    if (visibleUsers.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spaceLG),
          child: Center(child: Text('No users found matching filters.')),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == visibleUsers.length) {
            // Pagination controls at the bottom
            return _buildPaginationControls(
              totalRecords: totalRecords,
              totalPages: totalPages,
              currentPage: clampedPage,
              startIndex: startIndex,
              endIndex: endIndex,
            );
          }
          return _UserListTile(
            user: visibleUsers[index],
            onRoleChanged: (newRole) => _updateRole(visibleUsers[index], newRole),
          );
        },
        childCount: visibleUsers.length + 1,
      ),
    );
  }

  List<AdminUser> _getFilteredUsers() {
    final query = _searchQuery.toLowerCase();
    return _users.where((user) {
      final matchesRole = _roleFilter == 'ALL' || user.role.toUpperCase() == _roleFilter;
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

  Widget _buildPaginationControls({
    required int totalRecords,
    required int totalPages,
    required int currentPage,
    required int startIndex,
    required int endIndex,
  }) {
    final hasPrev = totalRecords > 0 && currentPage > 0;
    final hasNext = totalRecords > 0 && currentPage < totalPages - 1;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: hasPrev ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('${currentPage + 1} / $totalPages'),
          IconButton(
            onPressed: hasNext ? () => setState(() => _currentPage++) : null,
            icon: const Icon(Icons.chevron_right),
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
        status == 'APPROVED' ? 'Application approved.' : 'Application rejected.',
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

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  _MetricData(this.label, this.value, this.icon);
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;
  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, color: AppTheme.primaryPurple, size: 24),
          const Spacer(),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPartnerCard extends StatelessWidget {
  final AdminUser user;
  const _MiniPartnerCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.accentTeal.withOpacity(0.1),
            child: Text(
              user.fullName.isNotEmpty ? user.fullName[0] : '?',
              style: const TextStyle(color: AppTheme.accentTeal),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final PartnerApplicationRecord record;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApplicationCard({
    required this.record,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  record.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  record.submittedAt.toLocal().toString().split(' ')[0],
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            Text(record.email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Expertise: ${record.expertise}'),
            Text('Motivation: ${record.motivation}'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onReject,
                  style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UserListTile extends StatelessWidget {
  final AdminUser user;
  final Function(String) onRoleChanged;

  const _UserListTile({required this.user, required this.onRoleChanged});

  @override
  Widget build(BuildContext context) {
    final isMe = user.email == 'admin@gust.app'; // Prevent changing own role if needed

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: TextStyle(color: _getRoleColor(user.role)),
          ),
        ),
        title: Text(
          user.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email, style: const TextStyle(fontSize: 12)),
            Text(
              'Joined: ${user.createdAt?.split('T')[0] ?? 'Unknown'}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        trailing: DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButton<String>(
              value: user.role,
              icon: const Icon(Icons.arrow_drop_down, size: 20),
              isDense: true,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: const [
                DropdownMenuItem(value: 'USER', child: Text('User')),
                DropdownMenuItem(value: 'PARTNER', child: Text('Partner')),
                DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                DropdownMenuItem(value: 'ANONYMOUS', child: Text('Guest')),
              ],
              onChanged: isMe ? null : (val) {
                if (val != null && val != user.role) {
                  onRoleChanged(val);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN': return AppTheme.primaryPurple;
      case 'PARTNER': return AppTheme.accentTeal;
      case 'ANONYMOUS': return Colors.orange;
      default: return AppTheme.infoBlue;
    }
  }
}
