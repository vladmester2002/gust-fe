import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:another_flushbar/flushbar.dart'; // For notifications
import 'constants.dart';
import 'emotion.dart';
import 'sugar_log.dart';
import 'theme/app_theme.dart';
import 'widgets/gust_text_field.dart';
import 'widgets/gust_button.dart';
import 'data/models/local_sugar_log.dart';
import 'data/models/local_user.dart';
import 'repositories/auth_repository.dart';
import 'repositories/sugar_log_repository.dart';
import 'services/auth_helper.dart';

class SugarLogCreationDialog extends StatefulWidget {
  final Function(SugarLog) onCreated;
  final Function(SugarLog)? onUpdated;
  final Function(SugarLog)? onDeleted;
  final SugarLog? existingLog;

  const SugarLogCreationDialog({
    super.key,
    required this.onCreated,
    this.onUpdated,
    this.onDeleted,
    this.existingLog,
  });

  @override
  State<SugarLogCreationDialog> createState() => _SugarLogCreationDialogState();
}

class _SugarLogCreationDialogState extends State<SugarLogCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController sugarController;
  late final TextEditingController productNameController;
  late final TextEditingController sugarTypeController;
  late final TextEditingController contextNoteController;
  late final TextEditingController locationController;

  late DateTime selectedDate;
  late TimeOfDay selectedTime;
  late Emotion selectedEmotion;
  late bool wasCraving;
  bool _loading = false;
  bool _isGuestMode = false;
  final AuthRepository _authRepository = AuthRepository();
  final SugarLogRepository _logRepository = SugarLogRepository();
  LocalUser? _localUser;

  @override
  void initState() {
    super.initState();
    final log = widget.existingLog;
    // Always set selectedDate to today for both create & edit
    selectedDate = DateTime.now();
    sugarController = TextEditingController(text: log?.sugarGrams.toString() ?? '');
    productNameController = TextEditingController(text: log?.productName ?? '');
    sugarTypeController = TextEditingController(text: log?.sugarType ?? '');
    contextNoteController = TextEditingController(text: log?.contextNote ?? '');
    locationController = TextEditingController(text: log?.location ?? '');
    selectedTime = log != null
        ? TimeOfDay(hour: log.hour, minute: log.minute)
        : TimeOfDay.now();
    selectedEmotion = log?.emotion ?? Emotion.NEUTRAL;
    wasCraving = log?.wasCraving ?? false;
    _initGuestMode();
  }

  Future<void> _initGuestMode() async {
    final isGuest = await AuthHelper.isGuestSession();
    if (!mounted) {
      _isGuestMode = isGuest;
      return;
    }
    setState(() => _isGuestMode = isGuest);
  }

  Future<String?> _getToken() => AuthHelper.getNetworkToken();

  Future<LocalUser?> _ensureLocalUser() async {
    if (_localUser != null) return _localUser;
    final user = await _authRepository.getActiveUser();
    _localUser = user;
    return user;
  }

  Map<String, dynamic> _buildLogData() => {
        "sugarGrams": int.tryParse(sugarController.text) ?? 0,
        "date": DateFormat('yyyy-MM-dd').format(selectedDate),
        "hour": selectedTime.hour,
        "minute": selectedTime.minute,
        "productName": productNameController.text,
        "sugarType": sugarTypeController.text,
        "contextNote": contextNoteController.text,
        "emotion": selectedEmotion.name,
        "location": locationController.text,
        "wasCraving": wasCraving
      };

  LocalSugarLog _buildLocalSugarLog(int userId, {int? id}) {
    return LocalSugarLog(
      id: id,
      userId: userId,
      sugarGrams: int.tryParse(sugarController.text) ?? 0,
      date: DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
      hour: selectedTime.hour,
      minute: selectedTime.minute,
      productName: productNameController.text,
      sugarType: sugarTypeController.text,
      contextNote: contextNoteController.text,
      emotion: selectedEmotion.name.toUpperCase(),
      location: locationController.text,
      wasCraving: wasCraving,
      visibility: widget.existingLog?.visibility ?? 'PRIVATE',
      isDirty: true,
    );
  }

  SugarLog _mapLocalToSugarLog(LocalSugarLog log) {
    final emotion = Emotion.values.firstWhere(
      (e) => e.name == log.emotion.toUpperCase(),
      orElse: () => Emotion.NEUTRAL,
    );
    final identifier = log.id ?? log.remoteId ?? log.hashCode;
    return SugarLog(
      id: identifier,
      sugarGrams: log.sugarGrams,
      date: log.date,
      hour: log.hour,
      minute: log.minute,
      productName: log.productName ?? '',
      sugarType: log.sugarType ?? '',
      contextNote: log.contextNote ?? '',
      emotion: emotion,
      location: log.location ?? '',
      wasCraving: log.wasCraving,
      visibility: log.visibility,
    );
  }


  Future<void> _showFlushBar({
    required String message,
    required Color color,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) async {
    await Flushbar<void>(
      message: message,
      duration: duration,
      backgroundColor: color,
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      icon: icon != null
          ? Icon(icon, color: Colors.white)
          : null,
    ).show(context);
  }

  Future<void> _createLog() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // Always use repository for offline-first behavior
      final user = await _ensureLocalUser();
      if (user?.id == null) {
        if (mounted) {
          await _showFlushBar(
            message: 'Not logged in. Please login again.',
            color: Colors.red,
            icon: Icons.error,
          );
          setState(() => _loading = false);
        }
        return;
      }
      
      final localLog = _buildLocalSugarLog(user!.id!);
      final newId = await _logRepository.addLog(localLog);
      final saved = localLog.copyWith(id: newId);
      
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated(_mapLocalToSugarLog(saved));
      }
      await _showFlushBar(
        message: 'Sugar log added!',
        color: Colors.green,
        icon: Icons.check_circle,
      );
    } catch (e) {
      if (mounted) {
        await _showFlushBar(
          message: 'Failed to add log: $e',
          color: Colors.red,
          icon: Icons.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateLog() async {
    if (widget.existingLog == null || !mounted) return;
    setState(() => _loading = true);
    try {
      // Get user first
      final user = await _ensureLocalUser();
      if (user?.id == null) {
        if (mounted) {
          await _showFlushBar(
            message: 'Not logged in. Please login again.',
            color: Colors.red,
            icon: Icons.error,
          );
          setState(() => _loading = false);
        }
        return;
      }
      
      // Try to find the existing log in the database
      // widget.existingLog.id could be either local ID or remote ID
      // Always fetch from local cache to avoid server overwriting local changes
      final allLogs = await _logRepository.fetchLogs(userId: user!.id!, forceOffline: true);
      LocalSugarLog? existingLocal;
      
      try {
        existingLocal = allLogs.firstWhere(
          (log) => log.id == widget.existingLog!.id || log.remoteId == widget.existingLog!.id,
        );
      } catch (e) {
        // If not found, assume widget.existingLog.id is the local ID
        print('Could not find log in database, using existingLog.id as local ID');
      }
      
      // Build updated log with proper IDs
      final updatedLog = _buildLocalSugarLog(
        user.id!, 
        id: existingLocal?.id ?? widget.existingLog!.id,
      ).copyWith(
        remoteId: existingLocal?.remoteId,
      );
      
      await _logRepository.updateLog(updatedLog);
      
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdated?.call(_mapLocalToSugarLog(updatedLog));
      }
      await _showFlushBar(
        message: 'Sugar log updated!',
        color: Colors.green,
        icon: Icons.check_circle,
      );
    } catch (e) {
      if (mounted) {
        await _showFlushBar(
          message: 'Failed to update log: $e',
          color: Colors.red,
          icon: Icons.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteLog() async {
    if (widget.existingLog == null || !mounted) return;
    setState(() => _loading = true);
    try {
      // Get user first
      final user = await _ensureLocalUser();
      if (user?.id == null) {
        if (mounted) {
          await _showFlushBar(
            message: 'Not logged in. Please login again.',
            color: Colors.red,
            icon: Icons.error,
          );
          setState(() => _loading = false);
        }
        return;
      }
      
      // Try to find the existing log in the database
      // widget.existingLog.id could be either local ID or remote ID
      // Always fetch from local cache to avoid server overwriting local changes
      final allLogs = await _logRepository.fetchLogs(userId: user!.id!, forceOffline: true);
      int? localIdToDelete = widget.existingLog!.id;
      
      try {
        final existingLocal = allLogs.firstWhere(
          (log) => log.id == widget.existingLog!.id || log.remoteId == widget.existingLog!.id,
        );
        localIdToDelete = existingLocal.id;
      } catch (e) {
        // If not found, assume widget.existingLog.id is the local ID
        print('Could not find log in database, using existingLog.id as local ID');
      }
      
      // Delete using the correct local ID
      await _logRepository.deleteLog(localIdToDelete!, user.id!);
      
      if (mounted) {
        Navigator.pop(context);
        widget.onDeleted?.call(widget.existingLog!);
      }
      await _showFlushBar(
        message: 'Sugar log deleted!',
        color: Colors.green,
        icon: Icons.delete,
      );
    } catch (e) {
      if (mounted) {
        await _showFlushBar(
          message: 'Failed to delete log: $e',
          color: Colors.red,
          icon: Icons.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingLog != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppTheme.spaceMD),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPurple.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stunning Gradient Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6A1B9A), // Deep purple
                    Color(0xFF8E24AA), // Medium purple  
                    Color(0xFFAB47BC), // Light purple
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_rounded : Icons.add_circle_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? "Edit Sugar Log" : "Add Sugar Log",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEdit ? "Update your entry" : "Track your sugar intake",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spaceLG),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Essential Fields Section
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppTheme.primaryPurple,
                                      AppTheme.primaryPurple.withOpacity(0.5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "Essential Information",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "REQUIRED",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.errorRed,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          
                          // Sugar Amount Field (prominent)
                          GustTextField(
                            controller: sugarController,
                            label: "Sugar Amount (grams)",
                            prefixIcon: Icons.water_drop_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return "Required";
                              final n = int.tryParse(v);
                              if (n == null) return "Invalid number";
                              if (n > 999) return "Max 999g";
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          
                          // Product Name Field
                          GustTextField(
                            controller: productNameController,
                            label: "Product or Food Name",
                            prefixIcon: Icons.restaurant_menu_rounded,
                            validator: (v) => v == null || v.isEmpty ? "Required" : null,
                          ),
                          const SizedBox(height: 20),
                          
                          // Optional Details Section
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppTheme.textSecondary.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "Additional Details",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "Optional",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          
                          // Context Note Field
                          GustTextField(
                            controller: contextNoteController,
                            label: "Notes",
                            hint: "Any additional context or details...",
                            prefixIcon: Icons.edit_note_rounded,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),
                          
                          // When Section Header
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppTheme.primaryPurple,
                                      AppTheme.primaryPurple.withOpacity(0.5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "When",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          
                          // Date & Time Row (stunning design)
                          Row(
                            children: [
                              // Date - Today indicator
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppTheme.successGreen.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.calendar_today_rounded, 
                                            color: AppTheme.successGreen, 
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            "Date",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.successGreen,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        "Today",
                                        style: TextStyle(
                                          fontSize: 17,
                                          color: AppTheme.successGreen,
                                          fontWeight: FontWeight.w900,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('MMMM d, yyyy').format(selectedDate),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.successGreen.withOpacity(0.8),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Time - Interactive selector
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: selectedTime,
                                    );
                                    if (picked != null) {
                                      setState(() => selectedTime = picked);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.primaryPurple.withOpacity(0.15),
                                          AppTheme.primaryPurple.withOpacity(0.08),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppTheme.primaryPurple.withOpacity(0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.access_time_rounded, 
                                              color: AppTheme.primaryPurple, 
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              "Time",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.primaryPurple,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          selectedTime.format(context),
                                          style: const TextStyle(
                                            fontSize: 17,
                                            color: AppTheme.primaryPurple,
                                            fontWeight: FontWeight.w900,
                                            height: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.touch_app_rounded, 
                                              size: 10, 
                                              color: AppTheme.primaryPurple.withOpacity(0.7),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "Tap to change",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.primaryPurple.withOpacity(0.8),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // How You Felt Section
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppTheme.primaryPurple,
                                      AppTheme.primaryPurple.withOpacity(0.5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "How You Felt",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          
                          // How You Felt - Emotion Selector (Fixed height to prevent movement)
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundGrey.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.dividerGrey.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.mood_rounded, 
                                      size: 18, 
                                      color: AppTheme.primaryPurple,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "How did you feel?",
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Fixed height container to prevent layout shifts
                                SizedBox(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: Emotion.values.map((emotion) {
                                      final isSelected = selectedEmotion == emotion;
                                      return InkWell(
                                        onTap: () => setState(() => selectedEmotion = emotion),
                                        borderRadius: BorderRadius.circular(24),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: isSelected 
                                                ? LinearGradient(
                                                    colors: [
                                                      emotion.color,
                                                      emotion.color.withOpacity(0.8),
                                                    ],
                                                  )
                                                : null,
                                            color: isSelected 
                                                ? null
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(
                                              color: isSelected 
                                                  ? emotion.color
                                                  : AppTheme.dividerGrey.withOpacity(0.3),
                                              width: isSelected ? 2 : 1,
                                            ),
                                            boxShadow: isSelected ? [
                                              BoxShadow(
                                                color: emotion.color.withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ] : null,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                emotion.emoji,
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                emotion.label,
                                                style: TextStyle(
                                                  color: isSelected 
                                                      ? Colors.white
                                                      : AppTheme.textPrimary,
                                                  fontSize: 13,
                                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Craving Toggle - Stunning Design
                          InkWell(
                            onTap: () => setState(() => wasCraving = !wasCraving),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: wasCraving 
                                    ? LinearGradient(
                                        colors: [
                                          AppTheme.warningOrange,
                                          AppTheme.warningOrange.withOpacity(0.8),
                                        ],
                                      )
                                    : null,
                                color: wasCraving 
                                    ? null
                                    : AppTheme.backgroundGrey.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: wasCraving 
                                      ? AppTheme.warningOrange
                                      : AppTheme.dividerGrey.withOpacity(0.2),
                                  width: wasCraving ? 2 : 1,
                                ),
                                boxShadow: wasCraving ? [
                                  BoxShadow(
                                    color: AppTheme.warningOrange.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ] : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: wasCraving 
                                          ? Colors.white.withOpacity(0.2)
                                          : AppTheme.warningOrange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.bolt_rounded,
                                      color: wasCraving 
                                          ? Colors.white 
                                          : AppTheme.warningOrange,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Was this a craving?",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: wasCraving 
                                                ? Colors.white 
                                                : AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          wasCraving 
                                              ? "Yes, I was craving it" 
                                              : "Tap to mark as craving",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: wasCraving 
                                                ? Colors.white.withOpacity(0.9) 
                                                : AppTheme.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: wasCraving 
                                          ? Colors.white 
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: wasCraving 
                                            ? Colors.white 
                                            : AppTheme.dividerGrey,
                                        width: 2,
                                      ),
                                    ),
                                    child: wasCraving 
                                        ? const Icon(Icons.check_rounded, 
                                            size: 18, 
                                            color: AppTheme.warningOrange,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Actions Footer
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLG),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: AppTheme.dividerGrey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppTheme.radiusLarge),
                  bottomRight: Radius.circular(AppTheme.radiusLarge),
                ),
              ),
              child: isEdit
                  ? Column(
                      children: [
                        // Update button (full width)
                        SizedBox(
                          width: double.infinity,
                          child: GustButton(
                            text: "Update Log",
                            onPressed: _loading
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) return;
                                    await _updateLog();
                                  },
                            type: ButtonType.primary,
                            isLoading: _loading,
                            icon: Icons.check_circle,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceSM),
                        // Cancel and Delete row
                        Row(
                          children: [
                            Expanded(
                              child: GustButton(
                                text: "Cancel",
                                onPressed: _loading ? null : () => Navigator.pop(context),
                                type: ButtonType.secondary,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spaceSM),
                            Expanded(
                              child: GustButton(
                                text: "Delete",
                                onPressed: _loading ? null : _deleteLog,
                                type: ButtonType.danger,
                                icon: Icons.delete_outline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        // Add button (full width, prominent)
                        SizedBox(
                          width: double.infinity,
                          child: GustButton(
                            text: "Add Log",
                            onPressed: _loading
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) return;
                                    await _createLog();
                                  },
                            type: ButtonType.primary,
                            isLoading: _loading,
                            icon: Icons.check_circle,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceSM),
                        // Cancel button (secondary, full width)
                        SizedBox(
                          width: double.infinity,
                          child: GustButton(
                            text: "Cancel",
                            onPressed: _loading ? null : () => Navigator.pop(context),
                            type: ButtonType.secondary,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
