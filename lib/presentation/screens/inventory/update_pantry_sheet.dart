import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/models/food_item.dart';
import '../../../data/repositories/inventory_repository.dart';

class UpdatePantrySheet extends StatefulWidget {
  final FoodItem item;
  final InventoryRepository repo;

  const UpdatePantrySheet({
    super.key,
    required this.item,
    required this.repo,
  });

  @override
  State<UpdatePantrySheet> createState() => _UpdatePantrySheetState();
}

class _UpdatePantrySheetState extends State<UpdatePantrySheet> {
  late final TextEditingController _qtyController;
  late String _selectedUnit;
  late DateTime _expiryDate;
  late String _selectedStorage;
  bool _isSaving = false;
  bool _isDeleting = false;

  static const List<String> _units = [
    'Pieces',
    'Kg',
    'Grams',
    'Litres',
    'Packs',
    'Bags',
    'Bunch',
    'Cans',
    'Bottles',
  ];

  static const List<String> _storageLocations = [
    'Fridge',
    'Freezer',
    'Cupboard',
    'Counter',
    'Shelf',
    'Bag/Basket',
  ];

  @override
  void initState() {
    super.initState();
    _qtyController =
        TextEditingController(text: widget.item.quantity.toString());
    _selectedUnit = _units.contains(widget.item.unit)
        ? widget.item.unit
        : _units.first;
    _expiryDate = widget.item.expiryDate;
    _selectedStorage = _storageLocations.contains(widget.item.storageLocation)
        ? widget.item.storageLocation
        : _storageLocations.first;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate.isAfter(DateTime.now())
          ? _expiryDate
          : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _save() async {
    final qtyText = _qtyController.text.trim();
    if (qtyText.isEmpty) return;
    final qty = int.tryParse(qtyText);
    if (qty == null || qty < 0) {
      _showError('Please enter a valid quantity (0 or more).');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.repo.updateFoodItem(widget.item.id, {
        'quantity': qty,
        'unit': _selectedUnit,
        'expiryDate': _expiryDate,
        'storageLocation': _selectedStorage,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) _showError('Failed to update: $e');
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Item'),
        content:
            Text('Remove "${widget.item.name}" from your inventory?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await widget.repo.deleteFoodItem(widget.item.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) _showError('Failed to remove: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;
    final fieldBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    final border = isDark ? Colors.white12 : Colors.black12;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.name,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Delete button
                GestureDetector(
                  onTap: _isDeleting ? null : _delete,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.red),
                          )
                        : const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.item.category,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 20),

            // ── Quantity + Unit row ──────────────────────────────────────
            Text(
              'QUANTITY',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Minus button
                _CircleButton(
                  icon: Icons.remove,
                  isDark: isDark,
                  onTap: () {
                    final v = int.tryParse(_qtyController.text) ?? 0;
                    if (v > 0) {
                      _qtyController.text = '${v - 1}';
                    }
                  },
                ),
                const SizedBox(width: 12),

                // Qty text field
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: border),
                    ),
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Plus button
                _CircleButton(
                  icon: Icons.add,
                  isDark: isDark,
                  filled: true,
                  onTap: () {
                    final v = int.tryParse(_qtyController.text) ?? 0;
                    _qtyController.text = '${v + 1}';
                  },
                ),
                const SizedBox(width: 12),

                // Unit dropdown
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedUnit,
                      dropdownColor: sheetBg,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                      items: _units
                          .map((u) =>
                              DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedUnit = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Storage Location ─────────────────────────────────────────
            Text(
              'STORAGE LOCATION',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _storageLocations.map((loc) {
                final isSelected = _selectedStorage == loc;
                return GestureDetector(
                  onTap: () => setState(() => _selectedStorage = loc),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : fieldBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : border,
                      ),
                    ),
                    child: Text(
                      loc,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : textColor,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Expiry Date ──────────────────────────────────────────────
            Text(
              'EXPIRY DATE',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: AppTheme.primaryGreen, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _formatDate(_expiryDate),
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.edit_outlined, size: 16, color: subtitleColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Save button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Update Pantry',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final bool filled;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.isDark,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled
              ? AppTheme.primaryGreen
              : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.07)),
        ),
        child: Icon(
          icon,
          size: 20,
          color: filled ? Colors.white : (isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}
