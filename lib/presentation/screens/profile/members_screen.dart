import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../services/firebase_service.dart';

class MembersScreen extends StatefulWidget {
  final String householdId;
  final bool isAdmin;

  const MembersScreen({
    super.key,
    required this.householdId,
    required this.isAdmin,
  });

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final FirebaseService _firebase = FirebaseService();
  List<UserModel> _members = [];
  String? _adminUid;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    if (widget.householdId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final hDoc =
        await _firebase.households.doc(widget.householdId).get();
    if (!hDoc.exists) {
      setState(() => _loading = false);
      return;
    }

    final data = hDoc.data() as Map<String, dynamic>;
    final memberUids = List<String>.from(data['members'] ?? []);
    _adminUid = data['adminUid'] as String?;

    final List<UserModel> members = [];
    for (final uid in memberUids) {
      final userDoc = await _firebase.users.doc(uid).get();
      if (userDoc.exists) {
        members.add(UserModel.fromFirestore(userDoc));
      }
    }

    if (mounted) {
      setState(() {
        _members = members;
        _loading = false;
      });
    }
  }

  Future<void> _removeMember(UserModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member',
            style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen)),
        content: Text(
          'Remove ${member.firstName} ${member.lastName} from this household?',
          style: const TextStyle(fontFamily: 'Roboto'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(
                    fontFamily: 'Roboto', color: AppTheme.subtitleGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.red,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _firebase.households.doc(widget.householdId).update({
        'members': FieldValue.arrayRemove([member.id]),
      });
      _loadMembers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.primaryGreen;
    final subtitleColor = isDark ? AppTheme.darkSubtitle : AppTheme.subtitleGrey;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.white;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Household Members',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _members.isEmpty
              ? Center(
                  child: Text(
                    'No members found',
                    style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        color: subtitleColor),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  itemCount: _members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final isAdmin = member.id == _adminUid;
                    final isCurrentUser =
                        member.id == _firebase.currentUser?.uid;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isDark
                            ? []
                            : [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                AppTheme.primaryGreen.withValues(alpha: 0.12),
                            backgroundImage: member.photoUrl != null
                                ? NetworkImage(member.photoUrl!)
                                : null,
                            child: member.photoUrl == null
                                ? Text(
                                    '${member.firstName[0]}${member.lastName[0]}',
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${member.firstName} ${member.lastName}${isCurrentUser ? ' (You)' : ''}',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  member.email,
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 12,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? AppTheme.primaryGreen.withValues(alpha: 0.12)
                                  : Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isAdmin ? 'Admin' : 'Member',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isAdmin
                                    ? AppTheme.primaryGreen
                                    : Colors.blue,
                              ),
                            ),
                          ),
                          if (widget.isAdmin &&
                              !isCurrentUser &&
                              !isAdmin)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red, size: 20),
                              onPressed: () => _removeMember(member),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
