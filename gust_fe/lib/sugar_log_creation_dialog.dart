import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:another_flushbar/flushbar.dart'; // For notifications
import 'constants.dart';
import 'emotion.dart';
import 'SugarLog.dart';
import 'theme/app_theme.dart';
import 'widgets/gust_text_field.dart';
import 'widgets/gust_button.dart';

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
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
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
      final token = await _getToken();
      if (token == null) {
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
      // Don't override selectedDate, it is always today
      final url = Uri.parse('$baseUrl/api/sugarlogs');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(_buildLogData()),
      );
      if (!mounted) return;
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final log = SugarLog.fromJson(jsonDecode(response.body));
        widget.onCreated(log);
        Navigator.pop(context);
        await _showFlushBar(
          message: 'Sugar log added!',
          color: Colors.green,
          icon: Icons.check_circle,
        );
      } else {
        if (mounted) {
          await _showFlushBar(
            message: 'Failed to add log: ${response.body}',
            color: Colors.red,
            icon: Icons.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await _showFlushBar(
          message: 'Network error: $e',
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
      final token = await _getToken();
      if (token == null) {
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
      final url = Uri.parse('$baseUrl/api/sugarlogs/${widget.existingLog!.id}');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(_buildLogData()),
      );
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final log = SugarLog.fromJson(jsonDecode(response.body));
        widget.onUpdated?.call(log);
        Navigator.pop(context);
        await _showFlushBar(
          message: 'Sugar log updated!',
          color: Colors.green,
          icon: Icons.check_circle,
        );
      } else {
        if (mounted) {
          await _showFlushBar(
            message: 'Failed to update log: ${response.body}',
            color: Colors.red,
            icon: Icons.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await _showFlushBar(
          message: 'Network error: $e',
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
      final token = await _getToken();
      if (token == null) {
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
      final url = Uri.parse('$baseUrl/api/sugarlogs/${widget.existingLog!.id}');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (!mounted) return;
      
      if (response.statusCode == 204) {
        widget.onDeleted?.call(widget.existingLog!);
        Navigator.pop(context);
        await _showFlushBar(
          message: 'Sugar log deleted!',
          color: Colors.green,
          icon: Icons.delete,
        );
      } else {
        if (mounted) {
          await _showFlushBar(
            message: 'Failed to delete log: ${response.body}',
            color: Colors.red,
            icon: Icons.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await _showFlushBar(
          message: 'Network error: $e',
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
      insetPadding: EdgeInsets.all(AppTheme.spaceMD),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPurple.withOpacity(0.2),
              blurRadius: 30,
              offset: Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stunning Gradient Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
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
                    padding: EdgeInsets.all(12),
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
                  SizedBox(width: 16),
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
                        SizedBox(height: 2),
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
                padding: EdgeInsets.all(AppTheme.spaceLG),
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
                              SizedBox(width: 10),
                              Text(
                                "Essential Information",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(width: 6),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
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
                          SizedBox(height: 14),
                          
                          // Sugar Amount Field (prominent)
                          GustTextField(
                            controller: sugarController,
                            label: "Sugar Amount (grams)",
                            prefixIcon: Icons.water_drop_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.isEmpty ? "Required" : null,
                          ),
                          SizedBox(height: 12),
                          
                          // Product Name Field
                          GustTextField(
                            controller: productNameController,
                            label: "Product or Food Name",
                            prefixIcon: Icons.restaurant_menu_rounded,
                            validator: (v) => v == null || v.isEmpty ? "Required" : null,
                          ),
                          SizedBox(height: 20),
                          
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
                              SizedBox(width: 10),
                              Text(
                                "Additional Details",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
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
                          SizedBox(height: 14),
                          
                          // Context Note Field
                          GustTextField(
                            controller: contextNoteController,
                            label: "Notes",
                            hint: "Any additional context or details...",
                            prefixIcon: Icons.edit_note_rounded,
                            maxLines: 2,
                          ),
                          SizedBox(height: 20),
                          
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
                              SizedBox(width: 10),
                              Text(
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
                          SizedBox(height: 14),
                          
                          // Date & Time Row (stunning design)
                          Row(
                            children: [
                              // Date - Today indicator
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.all(14),
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
                                      Row(
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
                                      SizedBox(height: 8),
                                      Text(
                                        "Today",
                                        style: TextStyle(
                                          fontSize: 17,
                                          color: AppTheme.successGreen,
                                          fontWeight: FontWeight.w900,
                                          height: 1,
                                        ),
                                      ),
                                      SizedBox(height: 2),
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
                              SizedBox(width: 12),
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
                                    padding: EdgeInsets.all(14),
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
                                        Row(
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
                                        SizedBox(height: 8),
                                        Text(
                                          selectedTime.format(context),
                                          style: TextStyle(
                                            fontSize: 17,
                                            color: AppTheme.primaryPurple,
                                            fontWeight: FontWeight.w900,
                                            height: 1,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.touch_app_rounded, 
                                              size: 10, 
                                              color: AppTheme.primaryPurple.withOpacity(0.7),
                                            ),
                                            SizedBox(width: 4),
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
                          SizedBox(height: 20),
                          
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
                              SizedBox(width: 10),
                              Text(
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
                          SizedBox(height: 14),
                          
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
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
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
                                SizedBox(height: 12),
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
                                          duration: Duration(milliseconds: 200),
                                          padding: EdgeInsets.symmetric(
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
                                                offset: Offset(0, 2),
                                              ),
                                            ] : null,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                emotion.emoji,
                                                style: TextStyle(fontSize: 16),
                                              ),
                                              SizedBox(width: 6),
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
                          
                          SizedBox(height: 12),
                          
                          // Craving Toggle - Stunning Design
                          InkWell(
                            onTap: () => setState(() => wasCraving = !wasCraving),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              padding: EdgeInsets.all(16),
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
                                    offset: Offset(0, 4),
                                  ),
                                ] : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
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
                                  SizedBox(width: 12),
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
                                        SizedBox(height: 2),
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
                                        ? Icon(Icons.check_rounded, 
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
              padding: EdgeInsets.all(AppTheme.spaceLG),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: AppTheme.dividerGrey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                borderRadius: BorderRadius.only(
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
                        SizedBox(height: AppTheme.spaceSM),
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
                            SizedBox(width: AppTheme.spaceSM),
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
                        SizedBox(height: AppTheme.spaceSM),
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
