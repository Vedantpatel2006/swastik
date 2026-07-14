import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/event.dart';

/// Form widget for creating and editing events
class EventForm extends StatefulWidget {
  final Event? event;
  final Function(Event) onSubmit;
  final String templeId;

  const EventForm({
    super.key,
    this.event,
    required this.onSubmit,
    required this.templeId,
  });

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _additionalInfoController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isRecurring = false;
  RecurrenceType _recurrenceType = RecurrenceType.daily;
  int _recurrenceInterval = 1;
  List<int>? _daysOfWeek;
  int? _dayOfMonth;
  DateTime? _recurrenceUntil;
  int? _recurrenceCount;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _nameController.text = widget.event!.name;
      _descriptionController.text = widget.event!.description;
      _imageUrlController.text = widget.event!.imageUrl ?? '';
      _additionalInfoController.text =
          widget.event!.additionalInfo?.toString() ?? '';
      _startDate = widget.event!.startDate;
      _endDate = widget.event!.endDate;
      _isRecurring = widget.event!.isRecurring;

      if (widget.event!.recurrencePattern != null) {
        _recurrenceType = widget.event!.recurrencePattern!.type;
        _recurrenceInterval = widget.event!.recurrencePattern!.interval;
        _daysOfWeek = widget.event!.recurrencePattern!.daysOfWeek;
        _dayOfMonth = widget.event!.recurrencePattern!.dayOfMonth;
        _recurrenceUntil = widget.event!.recurrencePattern!.until;
        _recurrenceCount = widget.event!.recurrencePattern!.count;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : (_endDate ?? _startDate),
      firstDate: isStartDate ? DateTime.now() : _startDate,
      lastDate: DateTime(2030),
    );

    if (picked != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          isStartDate ? _startDate : (_endDate ?? _startDate),
        ),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          if (isStartDate) {
            _startDate = DateTime(
              picked.year,
              picked.month,
              picked.day,
              pickedTime.hour,
              pickedTime.minute,
            );
          } else {
            _endDate = DateTime(
              picked.year,
              picked.month,
              picked.day,
              pickedTime.hour,
              pickedTime.minute,
            );
          }
        });
      }
    }
  }

  Future<void> _selectRecurrenceEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _recurrenceUntil ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );

    if (picked != null && mounted) {
      setState(() {
        _recurrenceUntil = picked;
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Create recurrence pattern if event is recurring
      RecurrencePattern? recurrencePattern;
      if (_isRecurring) {
        recurrencePattern = RecurrencePattern(
          type: _recurrenceType,
          interval: _recurrenceInterval,
          daysOfWeek: _daysOfWeek,
          dayOfMonth: _dayOfMonth,
          until: _recurrenceUntil,
          count: _recurrenceCount,
        );
      }

      // Ensure endDate is set (required by Event model)
      final DateTime eventEndDate =
          _endDate ?? _startDate.add(const Duration(hours: 1));

      // Create event object
      final event = Event(
        id: widget.event?.id ?? '',
        templeId: widget.templeId,
        name: _nameController.text,
        description: _descriptionController.text,
        startDate: _startDate,
        endDate: eventEndDate,
        imageUrl: _imageUrlController.text.isEmpty
            ? null
            : _imageUrlController.text,
        additionalInfo: _additionalInfoController.text.isEmpty
            ? null
            : {'text': _additionalInfoController.text},
        isRecurring: _isRecurring,
        recurrencePattern: recurrencePattern,
      );

      widget.onSubmit(event);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an event name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Image URL (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _additionalInfoController,
              decoration: const InputDecoration(
                labelText: 'Additional Information (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Start Date & Time'),
              subtitle: Text(
                DateFormat('MMM d, yyyy - h:mm a').format(_startDate),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context, true),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('End Date & Time (Optional)'),
              subtitle: _endDate != null
                  ? Text(DateFormat('MMM d, yyyy - h:mm a').format(_endDate!))
                  : const Text('Not set'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context, false),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Recurring Event'),
              value: _isRecurring,
              onChanged: (value) {
                setState(() {
                  _isRecurring = value;
                });
              },
            ),
            if (_isRecurring) ..._buildRecurrenceOptions(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  widget.event == null ? 'Create Event' : 'Update Event',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecurrenceOptions() {
    return [
      const SizedBox(height: 8),
      const Divider(),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Recurrence Options',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      DropdownButtonFormField<RecurrenceType>(
        value: _recurrenceType,
        decoration: const InputDecoration(
          labelText: 'Recurrence Type',
          border: OutlineInputBorder(),
        ),
        items: RecurrenceType.values.map((type) {
          return DropdownMenuItem<RecurrenceType>(
            value: type,
            child: Text(_getRecurrenceTypeText(type)),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _recurrenceType = value!;
          });
        },
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: _recurrenceInterval.toString(),
              decoration: const InputDecoration(
                labelText: 'Repeat every',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _recurrenceInterval = int.tryParse(value) ?? 1;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                final interval = int.tryParse(value);
                if (interval == null || interval < 1) {
                  return 'Must be at least 1';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(_getIntervalUnitText())),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: RadioListTile<bool>(
              title: const Text('End after'),
              value: true,
              groupValue: _recurrenceCount != null,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _recurrenceCount = 10; // Default count
                    _recurrenceUntil = null;
                  }
                });
              },
            ),
          ),
          Expanded(
            child: _recurrenceCount != null
                ? TextFormField(
                    initialValue: _recurrenceCount.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Occurrences',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _recurrenceCount = int.tryParse(value);
                      });
                    },
                  )
                : const SizedBox(),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: RadioListTile<bool>(
              title: const Text('End by date'),
              value: false,
              groupValue: _recurrenceCount != null,
              onChanged: (value) {
                setState(() {
                  if (value == false) {
                    _recurrenceCount = null;
                    _recurrenceUntil = DateTime.now().add(
                      const Duration(days: 30),
                    );
                  }
                });
              },
            ),
          ),
          Expanded(
            child: _recurrenceUntil != null
                ? InkWell(
                    onTap: () => _selectRecurrenceEndDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        DateFormat('MMM d, yyyy').format(_recurrenceUntil!),
                      ),
                    ),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    ];
  }

  String _getRecurrenceTypeText(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
      case RecurrenceType.yearly:
        return 'Yearly';
    }
  }

  String _getIntervalUnitText() {
    switch (_recurrenceType) {
      case RecurrenceType.daily:
        return _recurrenceInterval > 1 ? 'days' : 'day';
      case RecurrenceType.weekly:
        return _recurrenceInterval > 1 ? 'weeks' : 'week';
      case RecurrenceType.monthly:
        return _recurrenceInterval > 1 ? 'months' : 'month';
      case RecurrenceType.yearly:
        return _recurrenceInterval > 1 ? 'years' : 'year';
    }
  }
}
