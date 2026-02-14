import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme/app_theme.dart';
import '../../../services/firebase_service.dart';
import '../../widgets/error_modal.dart';
import '../main/main_shell.dart';

class CreateHouseholdScreen extends StatefulWidget {
  const CreateHouseholdScreen({super.key});

  @override
  State<CreateHouseholdScreen> createState() => _CreateHouseholdScreenState();
}

class _CreateHouseholdScreenState extends State<CreateHouseholdScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _step = 1;
  String _householdType = 'Share';
  String? _expiryAlert;
  bool _isLoading = false;
  String? _createdHouseholdName;
  String? _inviteCode;

  static const List<String> _householdTypes = ['Share', 'Couple', 'Solo'];
  static const List<String> _expiryOptions = [
    '1 day before',
    '2 days before',
    '3 days before',
    '1 week before',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = DateTime.now().millisecondsSinceEpoch;
    return List.generate(9, (i) => chars[(rand + i * 7) % chars.length])
        .join();
  }

  Future<void> _onCreateHousehold() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseService().currentUser;
      final code = _generateInviteCode();
      final name = _nameController.text.trim();

      await FirebaseService().households.add({
        'name': name,
        'type': _householdType,
        'expiryAlert': _expiryAlert,
        'adminUid': user?.uid,
        'members': [user?.uid],
        'inviteCode': code,
        'createdAt': DateTime.now().toIso8601String(),
      });

      setState(() {
        _createdHouseholdName = name;
        _inviteCode = code;
        _step = 3;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorModal(context,
            title: 'Error', message: 'Failed to create household: $e');
      }
    }
  }

  Future<void> _shareViaWhatsApp(String code) async {
    final message = Uri.encodeComponent(
        'Join my SabiTrak household! Use this invite code: $code');
    final url = Uri.parse('https://wa.me/?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        showErrorModal(context,
            title: 'WhatsApp Not Found',
            message: 'Could not open WhatsApp. Please share the code manually.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: _step == 1
            ? _buildStep1()
            : _step == 2
                ? _buildStep2()
                : _buildSuccess(),
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Create Household – Step 1: Household Details',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Household Name',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter household name',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppTheme.fieldBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppTheme.primaryGreen, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Colors.red, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter a household name' : null,
            ),
            const SizedBox(height: 6),
            const Text(
              'This name will be visible to all household members.',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: AppTheme.subtitleGrey,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  setState(() => _step = 2);
                }
              },
              child: const Text('Proceed'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.backButtonColor),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Create Household - Step 2',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Household Preferences',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Select Household Type:',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          ..._householdTypes.map((type) => RadioListTile<String>(
                title: Text(type,
                    style: const TextStyle(
                        fontFamily: 'Roboto', color: AppTheme.primaryGreen)),
                value: type,
                groupValue: _householdType,
                activeColor: AppTheme.primaryGreen,
                onChanged: (v) => setState(() => _householdType = v!),
                contentPadding: EdgeInsets.zero,
              )),
          const SizedBox(height: 16),
          const Text(
            'Default Expiry Alert (Optional):',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _expiryAlert,
            hint: const Text('Select an option'),
            items: _expiryOptions
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: (v) => setState(() => _expiryAlert = v),
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppTheme.fieldBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppTheme.primaryGreen, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The creator becomes the household admin.',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              color: AppTheme.subtitleGrey,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _onCreateHousehold,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.white))
                : const Text('Create Household'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Household Created!',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Household Name: $_createdHouseholdName\nRole: Admin',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: AppTheme.subtitleGrey,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Invite Code:',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  color: AppTheme.subtitleGrey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.fieldBorderColor),
                ),
                child: Text(
                  _inviteCode ?? '',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _inviteCode ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Code copied!'),
                              backgroundColor: AppTheme.primaryGreen),
                        );
                      },
                      child: const Text('Copy Code'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _shareViaWhatsApp(_inviteCode ?? ''),
                      child: const Text('Share via WhatsApp'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.backButtonColor),
                child: const Text('Invite Later'),
              ),
              const SizedBox(height: 4),
              const Text(
                'Inviting members is optional.',
                style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: AppTheme.subtitleGrey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (route) => false,
                  );
                },
                child: const Text('Continue to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
