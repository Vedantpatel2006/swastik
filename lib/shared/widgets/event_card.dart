import 'package:flutter/material.dart';
import '../models/event.dart';
import 'package:intl/intl.dart';

/// Card widget for displaying event information
class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;
  final bool showTemple;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.showTemple = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildContent(),
              const SizedBox(height: 12),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return EventCardHeader(isRecurring: event.isRecurring);
  }

  Widget _buildContent() {
    return EventCardContent(name: event.name, description: event.description);
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          _formatEventDate(),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const Spacer(),
        if (event.imageUrl != null)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(event.imageUrl!),
                fit: BoxFit.cover,
              ),
            ),
          ),
      ],
    );
  }

  String _formatEventDate() {
    final now = DateTime.now();
    final eventDate = event.startDate;

    if (eventDate.year == now.year &&
        eventDate.month == now.month &&
        eventDate.day == now.day) {
      return 'Today';
    } else if (eventDate.difference(now).inDays == 1) {
      return 'Tomorrow';
    } else if (eventDate.difference(now).inDays < 7) {
      return DateFormat('EEEE').format(eventDate);
    } else {
      return DateFormat('MMM d').format(eventDate);
    }
  }
}

/// Optimized header widget for event cards
class EventCardHeader extends StatelessWidget {
  final bool isRecurring;

  const EventCardHeader({super.key, required this.isRecurring});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'EVENT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFF6B35),
            ),
          ),
        ),
        const Spacer(),
        if (isRecurring)
          const Icon(Icons.repeat, size: 16, color: Color(0xFF6B7280)),
      ],
    );
  }
}

/// Optimized content widget for event cards
class EventCardContent extends StatelessWidget {
  final String name;
  final String description;

  const EventCardContent({
    super.key,
    required this.name,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
