import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'israel_time.dart';

/// A manager-only, web-facing way to request a recorded court clip without an
/// ESP32 button press. The callable function performs the actual manager
/// authorization; keeping that check on the server prevents this screen from
/// becoming a privilege boundary.
class ManagerVideoRequestScreen extends StatefulWidget {
  const ManagerVideoRequestScreen({super.key});

  @override
  State<ManagerVideoRequestScreen> createState() =>
      _ManagerVideoRequestScreenState();
}

class _ManagerVideoRequestScreenState extends State<ManagerVideoRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  int _courtNumber = 1;
  bool _isSubmitting = false;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    final now = IsraelTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedTime = TimeOfDay.fromDateTime(now);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String get _dateValue => DateFormat('yyyy-MM-dd').format(_selectedDate);

  String get _timeValue => '${_selectedTime.hour.toString().padLeft(2, '0')}:'
      '${_selectedTime.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: IsraelTime.now(),
      helpText: 'בחירת תאריך הקטע',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _successMessage = null;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: 'בחירת שעת הקטע',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _selectedTime = picked;
      _successMessage = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _successMessage = null;
    });

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('requestVideoClipForManager');
      final result = await callable.call(<String, dynamic>{
        'courtNumber': _courtNumber,
        'date': _dateValue,
        'time': _timeValue,
        'recipientEmail': _emailController.text.trim(),
      });

      final response = result.data;
      final requestId =
          response is Map ? response['requestId']?.toString() : null;
      final deduplicated = response is Map && response['deduplicated'] == true;
      final message = deduplicated
          ? 'כבר קיימת בקשה זהה. לא נשלחה בקשה נוספת.'
          : requestId == null || requestId.isEmpty
              ? 'בקשת הווידאו נשלחה לעיבוד.'
              : 'בקשת הווידאו נשלחה לעיבוד (מספר בקשה: $requestId).';

      if (!mounted) return;
      setState(() => _successMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green[700]),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showError(_firebaseErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      _showError('שליחת בקשת הווידאו נכשלה. נסו שוב מאוחר יותר.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _firebaseErrorMessage(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'אין הרשאה לשלוח בקשת וידאו.';
      case 'invalid-argument':
        return error.message ?? 'יש לבדוק את התאריך, השעה, המגרש והמייל.';
      case 'not-found':
        return error.message ?? 'לא נמצא קטע וידאו מתאים לבקשה.';
      case 'failed-precondition':
        return error.message ?? 'לא ניתן לעבד את הבקשה במצב הנוכחי.';
      case 'resource-exhausted':
        return error.message ?? 'הבקשה הוגשה לאחרונה. נסו שוב בעוד זמן קצר.';
      case 'unavailable':
        return 'שירות הווידאו אינו זמין כרגע. נסו שוב מאוחר יותר.';
      default:
        return error.message ?? 'שליחת בקשת הווידאו נכשלה.';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('שליחת וידאו ידנית')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'בקשת קטע וידאו',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'הקטע יישלח לכתובת המייל שתוזן. התאריך והשעה הם לפי שעון ישראל.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<int>(
                        initialValue: _courtNumber,
                        decoration: const InputDecoration(
                          labelText: 'מגרש',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('מגרש 1')),
                          DropdownMenuItem(value: 2, child: Text('מגרש 2')),
                          DropdownMenuItem(value: 3, child: Text('מגרש 3')),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _courtNumber = value;
                                  _successMessage = null;
                                });
                              },
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _pickDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          'תאריך: ${DateFormat('dd.MM.yyyy').format(_selectedDate)}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _pickTime,
                        icon: const Icon(Icons.schedule),
                        label: Text('שעה: $_timeValue'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_isSubmitting,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: ui.TextDirection.ltr,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'כתובת מייל לקבלת הווידאו',
                          hintText: 'name@example.com',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'יש להזין כתובת מייל.';
                          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(email)) {
                            return 'כתובת המייל אינה תקינה.';
                          }
                          return null;
                        },
                      ),
                      if (_successMessage != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: scheme.onPrimaryContainer),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _successMessage!,
                                  style: TextStyle(
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label: Text(
                          _isSubmitting
                              ? 'שולח בקשה…'
                              : 'שליחת בקשה לעיבוד וידאו',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
