import 'package:flutter/material.dart';

class FamilyMemberTile extends StatelessWidget {
  const FamilyMemberTile({
    required this.initials,
    required this.name,
    required this.relationship,
    required this.status,
    required this.updated,
    required this.color,
    this.phoneNumber,
    this.onRemove,
    this.onMessage,
    super.key,
  });

  final String initials;
  final String name;
  final String relationship;
  final String status;
  final String updated;
  final Color color;
  final String? phoneNumber;
  final VoidCallback? onRemove;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: const BorderSide(color: Color(0xFFDCE5EF)),
      ),
      child: InkWell(
        onTap: _ignoreTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.13),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Color(0xFF173A5F),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name ($relationship)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF102E58),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (phoneNumber != null &&
                        phoneNumber!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_rounded,
                            size: 12,
                            color: Color(0xFF4E6885),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              phoneNumber!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF4E6885),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      updated.replaceFirst('Updated: ', 'Updated '),
                      style: const TextStyle(
                        color: Color(0xFF687B92),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (onMessage != null)
                IconButton(
                  onPressed: onMessage,
                  tooltip: 'Send message',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF1456B7),
                    size: 20,
                  ),
                ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Remove member',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.person_remove_rounded,
                    color: Color(0xFFD23B3B),
                    size: 21,
                  ),
                ),
              if (onMessage == null && onRemove == null) ...[
                const SizedBox(width: 9),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF4E6885),
                  size: 23,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _ignoreTap() {}
