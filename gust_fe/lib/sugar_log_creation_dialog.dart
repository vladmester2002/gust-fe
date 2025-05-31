import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'emotion.dart';
import 'SugarLog.dart';

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
    sugarController = TextEditingController(text: log?.sugarGrams.toString() ?? '');
    productNameController = TextEditingController(text: log?.productName ?? '');
    sugarTypeController = TextEditingController(text: log?.sugarType ?? '');
    contextNoteController = TextEditingController(text: log?.contextNote ?? '');
    locationController = TextEditingController(text: log?.location ?? '');
    selectedDate = log?.date ?? DateTime.now();
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

  Future<void> _createLog() async {
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not logged in. Please login again.')),
        );
        setState(() => _loading = false);
        return;
      }
      // Always use today's date when creating a new log
      selectedDate = DateTime.now();
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sugar log added!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add log: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not logged in. Please login again.')),
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sugar log updated!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update log: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not logged in. Please login again.')),
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sugar log deleted!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete log: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.existingLog == null ? "Log Sugar Intake" : "Edit Sugar Log"),
      content: StatefulBuilder(
        builder: (context, setState) {
          return SizedBox(
            width: 350,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: sugarController,
                      decoration: const InputDecoration(labelText: "Sugar (g)"),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty ? "Required" : null,
                    ),
                    TextFormField(
                      controller: productNameController,
                      decoration: const InputDecoration(labelText: "Product/Food Name"),
                    ),
                    TextFormField(
                      controller: sugarTypeController,
                      decoration: const InputDecoration(labelText: "Sugar Type"),
                    ),
                    TextFormField(
                      controller: contextNoteController,
                      decoration: const InputDecoration(labelText: "Context Note"),
                    ),
                    TextFormField(
                      controller: locationController,
                      decoration: const InputDecoration(labelText: "Location"),
                    ),
                    const SizedBox(height: 12),
                    // Date row: Show picker only when editing
                    if (widget.existingLog != null)
                      Row(
                        children: [
                          Expanded(
                            child: Text("Date: ${DateFormat.yMd().format(selectedDate)}"),
                          ),
                          IconButton(
                            icon: Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => selectedDate = picked);
                              }
                            },
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Date: ${DateFormat.yMd().format(DateTime.now())}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),

                    Row(
                      children: [
                        Expanded(
                          child: Text("Time: ${selectedTime.format(context)}"),
                        ),
                        IconButton(
                          icon: Icon(Icons.access_time, color: theme.colorScheme.primary),
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
                    DropdownButtonFormField<Emotion>(
                      value: selectedEmotion,
                      onChanged: (e) => setState(() => selectedEmotion = e!),
                      items: Emotion.values.map((e) => DropdownMenuItem(
                        value: e,
                        child: Text("${e.emoji} ${e.label}"),
                      )).toList(),
                      decoration: const InputDecoration(labelText: "Emotion"),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Was craving?"),
                        Switch(
                          value: wasCraving,
                          onChanged: (v) => setState(() => wasCraving = v),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      actions: [
        if (widget.existingLog != null)
          TextButton(
            onPressed: _loading ? null : _deleteLog,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _loading
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (widget.existingLog == null) {
                    // For create, always use current date (set just before call)
                    await _createLog();
                  } else {
                    await _updateLog();
                  }
                },
          child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.existingLog == null ? "Log" : "Update"),
        ),
      ],
    );
  }
}
