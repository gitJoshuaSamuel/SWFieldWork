import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class CollegeOptionsPage extends StatefulWidget {
  const CollegeOptionsPage({super.key});

  @override
  State<CollegeOptionsPage> createState() => _CollegeOptionsPageState();
}

class _CollegeOptionsPageState extends State<CollegeOptionsPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoadingList = true;
  bool _isAdding = false;
  int? _professorSecretCode;

  final TextEditingController _valueController = TextEditingController();
  String _selectedCategory = 'class'; // Default category key

  List<Map<String, dynamic>> _options = [];
  String _activeFilter = 'all'; // Filter state

  final List<Map<String, String>> _categories = [
    {'db': 'class', 'ui': 'Class'},
    {'db': 'batch', 'ui': 'Batch'},
    {'db': 'semester', 'ui': 'Semester'},
    {'db': 'specialisation', 'ui': 'Specialisation'},
    {'db': 'organisation', 'ui': 'Organisation Placed'},
    {'db': 'agency_supervisor', 'ui': 'Agency Supervisor'},
    {'db': 'faculty_supervisor', 'ui': 'Faculty Supervisor'},
    {'db': 'professor', 'ui': 'Related Professor'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfessorProfile();
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _loadProfessorProfile() async {
    setState(() => _isLoadingList = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // Query profiles table
        final profileResponse = await supabase
            .from('profiles')
            .select('secret_code, college_code')
            .eq('id', user.id)
            .maybeSingle();

        int? code;
        if (profileResponse != null) {
          final rawCode = profileResponse['secret_code'] ?? profileResponse['college_code'];
          if (rawCode != null) {
            code = int.tryParse(rawCode.toString());
          }
        }

        // Fallback to metadata
        if (code == null) {
          final rawCode = user.userMetadata?['secret_code'] ?? user.userMetadata?['college_code'];
          if (rawCode != null) {
            code = int.tryParse(rawCode.toString());
          }
        }

        if (code != null) {
          _professorSecretCode = code;
          await _fetchOptions();
        } else {
          setState(() => _isLoadingList = false);
        }
      } else {
        setState(() => _isLoadingList = false);
      }
    } catch (e) {
      debugPrint("Error loading professor profile: $e");
      setState(() => _isLoadingList = false);
    }
  }

  Future<void> _fetchOptions() async {
    setState(() => _isLoadingList = true);
    try {
      final response = await supabase
          .from('college_options')
          .select()
          .eq('college_code', _professorSecretCode!)
          .order('value');

      setState(() {
        _options = List<Map<String, dynamic>>.from(response);
        _isLoadingList = false;
      });
    } catch (e) {
      debugPrint("Error fetching options: $e");
      setState(() => _isLoadingList = false);
    }
  }

  Future<void> _addOption() async {
    if (!_formKey.currentState!.validate()) return;
    if (_professorSecretCode == null) return;

    setState(() => _isAdding = true);
    final val = _valueController.text.trim();

    try {
      await supabase.from('college_options').insert({
        'college_code': _professorSecretCode!,
        'category': _selectedCategory,
        'value': val,
      });

      _valueController.clear();
      _fetchOptions();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Option added successfully!",
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error adding option: $e"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteOption(String id) async {
    try {
      await supabase.from('college_options').delete().eq('id', id);
      _fetchOptions();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Option deleted successfully!",
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting option: $e"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'class':
        return Colors.blue;
      case 'batch':
        return Colors.orange;
      case 'semester':
        return Colors.purple;
      case 'specialisation':
        return Colors.teal;
      case 'organisation':
        return Colors.indigo;
      case 'agency_supervisor':
        return Colors.brown;
      case 'faculty_supervisor':
        return Colors.deepPurple;
      case 'professor':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  String _getCategoryUIName(String dbName) {
    final match = _categories.firstWhere(
      (element) => element['db'] == dbName,
      orElse: () => {'ui': dbName},
    );
    return match['ui']!;
  }

  @override
  Widget build(BuildContext context) {
    final filteredOptions = _activeFilter == 'all'
        ? _options
        : _options.where((item) => item['category'] == _activeFilter).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _professorSecretCode == null
          ? Center(
              child: Text(
                "Professor profile not verified. Check secret code.",
                style: GoogleFonts.inter(),
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  // Form Area (Add Options)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.grey[100]!, width: 1.5),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.settings_suggest_rounded, color: Colors.teal),
                              const SizedBox(width: 8),
                              Text(
                                "Add Dropdown Value",
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              // Category Dropdown
                              Expanded(
                                flex: 4,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedCategory,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Colors.black),
                                    ),
                                  ),
                                  dropdownColor: Colors.white,
                                  style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                                  items: _categories
                                      .map((cat) => DropdownMenuItem(
                                            value: cat['db']!,
                                            child: Text(cat['ui']!),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedCategory = val);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Text Value Input
                              Expanded(
                                flex: 5,
                                child: TextFormField(
                                  controller: _valueController,
                                  decoration: InputDecoration(
                                    hintText: "Enter Value (e.g. MSW-I)",
                                    hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Colors.black),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Colors.redAccent),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Colors.redAccent),
                                    ),
                                  ),
                                  style: GoogleFonts.inter(fontSize: 13),
                                  validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _isAdding ? null : _addOption,
                            icon: _isAdding
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.add_circle_outline_rounded, size: 16),
                            label: Text(
                              _isAdding ? "Saving..." : "Add to Dropdown Options",
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text("All Options"),
                          selected: _activeFilter == 'all',
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _activeFilter == 'all' ? Colors.white : Colors.black87,
                          ),
                          selectedColor: Colors.black,
                          checkmarkColor: Colors.white,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onSelected: (val) => setState(() => _activeFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        ..._categories.map((cat) {
                          final dbName = cat['db']!;
                          final uiName = cat['ui']!;
                          final isSelected = _activeFilter == dbName;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(uiName),
                              selected: isSelected,
                              labelStyle: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                              selectedColor: _getCategoryColor(dbName),
                              checkmarkColor: Colors.white,
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onSelected: (val) => setState(() => _activeFilter = dbName),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // List of options
                  Expanded(
                    child: _isLoadingList
                        ? const Center(child: CircularProgressIndicator(color: Colors.black))
                        : filteredOptions.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[350]),
                                    const SizedBox(height: 12),
                                    Text(
                                      "No options configured",
                                      style: GoogleFonts.inter(
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: filteredOptions.length,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemBuilder: (context, i) {
                                  final option = filteredOptions[i];
                                  final catDb = option['category']?.toString() ?? '';
                                  final color = _getCategoryColor(catDb);

                                  return Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(color: Colors.grey[100]!, width: 1.5),
                                    ),
                                    color: Colors.white,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      leading: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _getCategoryUIName(catDb),
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        option['value'] ?? '',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                        onPressed: () => _showDeleteConfirmation(option),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> option) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Delete Option?",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to delete '${option['value']}' from the ${_getCategoryUIName(option['category'])} options?",
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            child: Text("Cancel", style: GoogleFonts.inter(color: Colors.black)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text("Delete", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteOption(option['id']?.toString() ?? '');
            },
          ),
        ],
      ),
    );
  }
}
