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
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      if (token == null) {
        await _showFlushBar(
          message: 'Not logged in. Please login again.',
          color: Colors.red,
          icon: Icons.error,
        );
        setState(() => _loading = false);
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
        await _showFlushBar(
          message: 'Failed to add log: ${response.body}',
          color: Colors.red,
          icon: Icons.error,
        );
      }
    } catch (e) {
      await _showFlushBar(
        message: 'Network error: $e',
        color: Colors.red,
        icon: Icons.error,
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateLog() async {
    if (widget.existingLog == null) return;
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      if (token == null) {
        await _showFlushBar(
          message: 'Not logged in. Please login again.',
          color: Colors.red,
          icon: Icons.error,
        );
        setState(() => _loading = false);
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
        await _showFlushBar(
          message: 'Failed to update log: ${response.body}',
          color: Colors.red,
          icon: Icons.error,
        );
      }
    } catch (e) {
      await _showFlushBar(
        message: 'Network error: $e',
        color: Colors.red,
        icon: Icons.error,
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteLog() async {
    if (widget.existingLog == null) return;
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      if (token == null) {
        await _showFlushBar(
          message: 'Not logged in. Please login again.',
          color: Colors.red,
          icon: Icons.error,
        );
        setState(() => _loading = false);
        return;
      }
      final url = Uri.parse('$baseUrl/api/sugarlogs/${widget.existingLog!.id}');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 204) {
        widget.onDeleted?.call(widget.existingLog!);
        Navigator.pop(context);
        await _showFlushBar(
          message: 'Sugar log deleted!',
          color: Colors.green,
          icon: Icons.delete,
        );
      } else {
        await _showFlushBar(
          message: 'Failed to delete log: ${response.body}',
          color: Colors.red,
          icon: Icons.error,
        );
      }
    } catch (e) {
      await _showFlushBar(
        message: 'Network error: $e',
        color: Colors.red,
        icon: Icons.error,
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingLog != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(AppTheme.spaceMD),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.shadowLevel2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(AppTheme.spaceLG),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusLarge),
                  topRight: Radius.circular(AppTheme.radiusLarge),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppTheme.spaceSM),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit : Icons.add_circle_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: AppTheme.spaceMD),
                  Expanded(
                    child: Text(
                      isEdit ? "Edit Sugar Log" : "Log Sugar Intake",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
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
                          // Sugar Amount Field
                          GustTextField(
                            controller: sugarController,
                            label: "Sugar (g)",
                            prefixIcon: Icons.local_drink,
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.isEmpty ? "Required" : null,
                          ),
                          SizedBox(height: AppTheme.spaceMD),
                          
                          // Product Name Field
                          GustTextField(
                            controller: productNameController,
                            label: "Product/Food Name",
                            prefixIcon: Icons.fastfood,
                          ),
                          SizedBox(height: AppTheme.spaceMD),
                          
                          // Sugar Type Field
                          GustTextField(
                            controller: sugarTypeController,
                            label: "Sugar Type",
                            prefixIcon: Icons.category,
                          ),
                          SizedBox(height: AppTheme.spaceMD),
                          
                          // Context Note Field
                          GustTextField(
                            controller: contextNoteController,
                            label: "Context Note",
                            prefixIcon: Icons.notes,
                            maxLines: 2,
                          ),
                          SizedBox(height: AppTheme.spaceMD),
                          
                          // Location Field
                          GustTextField(
                            controller: locationController,
                            label: "Location",
                            prefixIcon: Icons.location_on,
                          ),
                          SizedBox(height: AppTheme.spaceLG),
                          
                          // Date Section
                          Container(
                            padding: EdgeInsets.all(AppTheme.spaceMD),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundGrey,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(color: AppTheme.dividerGrey.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(AppTheme.spaceSM),
                                  decoration: BoxDecoration(
                                    color: AppTheme.infoBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  ),
                                  child: Icon(Icons.today, color: AppTheme.infoBlue, size: 20),
                                ),
                                SizedBox(width: AppTheme.spaceMD),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Date",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${DateFormat.yMd().format(selectedDate)} (today only)",
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: AppTheme.spaceMD),
                          
                          // Time Section
                          Container(
                            padding: EdgeInsets.all(AppTheme.spaceMD),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundGrey,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(color: AppTheme.dividerGrey.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(AppTheme.spaceSM),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryPurple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  ),
                                  child: Icon(Icons.access_time, color: AppTheme.primaryPurple, size: 20),
                                ),
                                SizedBox(width: AppTheme.spaceMD),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Time",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        selectedTime.format(context),
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit, color: AppTheme.primaryPurple, size: 20),
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: selectedTime,
                                    );
                                    if (picked != null) {
                                      setState(() => selectedTime = picked);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: AppTheme.spaceSM),
                          
                          // Tip
                          Container(
                            padding: EdgeInsets.all(AppTheme.spaceSM),
                            decoration: BoxDecoration(
                              color: AppTheme.infoBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lightbulb_outline, color: AppTheme.infoBlue, size: 16),
                                SizedBox(width: AppTheme.spaceSM),
                                Expanded(
                                  child: Text(
                                    "Tip: Pick the time you actually consumed sugar for accurate analytics.",
                                    style: TextStyle(
                                      color: AppTheme.infoBlue,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: AppTheme.spaceLG),
                          
                          // Emotion Dropdown
                          Text(
                            "Emotion",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: AppTheme.spaceSM),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundGrey,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(color: AppTheme.dividerGrey.withOpacity(0.3)),
                            ),
                            child: DropdownButtonFormField<Emotion>(
                              value: selectedEmotion,
                              onChanged: (e) => setState(() => selectedEmotion = e!),
                              items: Emotion.values.map((e) => DropdownMenuItem(
                                value: e,
                                child: Row(
                                  children: [
                                    Text(e.emoji, style: const TextStyle(fontSize: 20)),
                                    SizedBox(width: AppTheme.spaceSM),
                                    Text(e.label, style: TextStyle(color: AppTheme.textPrimary)),
                                  ],
                                ),
                              )).toList(),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              icon: Icon(Icons.arrow_drop_down, color: AppTheme.primaryPurple),
                            ),
                          ),
                          SizedBox(height: AppTheme.spaceLG),
                          
                          // Craving Switch
                          Container(
                            padding: EdgeInsets.all(AppTheme.spaceMD),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundGrey,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(color: AppTheme.dividerGrey.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(AppTheme.spaceSM),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningOrange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  ),
                                  child: Icon(Icons.bolt, color: AppTheme.warningOrange, size: 20),
                                ),
                                SizedBox(width: AppTheme.spaceMD),
                                Expanded(
                                  child: Text(
                                    "Was craving?",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: wasCraving,
                                  onChanged: (v) => setState(() => wasCraving = v),
                                  activeColor: AppTheme.warningOrange,
                                ),
                              ],
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
                color: AppTheme.backgroundGrey,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppTheme.radiusLarge),
                  bottomRight: Radius.circular(AppTheme.radiusLarge),
                ),
              ),
              child: isEdit
                  ? Row(
                      children: [
                        Expanded(
                          child: GustButton(
                            text: "Delete",
                            onPressed: _loading ? null : _deleteLog,
                            type: ButtonType.danger,
                            icon: Icons.delete_outline,
                          ),
                        ),
                        SizedBox(width: AppTheme.spaceSM),
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
                            text: "Update",
                            onPressed: _loading
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) return;
                                    await _updateLog();
                                  },
                            type: ButtonType.primary,
                            isLoading: _loading,
                            icon: Icons.check,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              side: BorderSide(color: AppTheme.dividerGrey),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                            ),
                            child: const Text("Cancel"),
                          ),
                        ),
                        SizedBox(width: AppTheme.spaceMD),
                        Expanded(
                          flex: 2,
                          child: GustButton(
                            text: "Log",
                            onPressed: _loading
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) return;
                                    await _createLog();
                                  },
                            type: ButtonType.primary,
                            isLoading: _loading,
                            icon: Icons.add,
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
