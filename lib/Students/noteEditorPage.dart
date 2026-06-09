import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class NoteEditorPage extends StatefulWidget {
  final Map<String, dynamic>? note; // Null if creating a new note

  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final supabase = Supabase.instance.client;
  
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late DateTime _selectedDate;
  
  String? _noteId;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  Timer? _autoSaveTimer;
  String _saveStatus = "Saved";

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?['title'] ?? '');
    _descController = TextEditingController(text: widget.note?['description'] ?? '');
    
    final noteDateStr = widget.note?['note_date'];
    if (noteDateStr != null) {
      _selectedDate = DateTime.parse(noteDateStr).toLocal();
    } else {
      _selectedDate = DateTime.now();
    }
    
    _noteId = widget.note?['id'];

    // Listeners to detect changes
    _titleController.addListener(_onContentChanged);
    _descController.addListener(_onContentChanged);

    // Start auto-save timer (every 3 seconds)
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_hasUnsavedChanges) {
        _saveNote();
      }
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (mounted) {
      setState(() {
        _hasUnsavedChanges = true;
        _saveStatus = "Unsaved changes";
      });
    }
  }

  Future<void> _saveNote() async {
    if (!_hasUnsavedChanges) return;
    
    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    
    // Don't auto-save if both title and description are blank for a new note
    if (_noteId == null && title.isEmpty && description.isEmpty) {
      return;
    }

    // Use a fallback title if user hasn't typed one
    final displayTitle = title.isEmpty ? "Untitled Note" : title;

    if (mounted) {
      setState(() {
        _isSaving = true;
        _saveStatus = "Saving...";
      });
    }

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = {
        'user_id': userId,
        'title': displayTitle,
        'description': description,
        'note_date': _selectedDate.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (_noteId == null) {
        // Insert
        final response = await supabase
            .from('student_notes')
            .insert(data)
            .select('id')
            .single();
        _noteId = response['id'];
      } else {
        // Update
        await supabase
            .from('student_notes')
            .update(data)
            .eq('id', _noteId!);
      }

      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
          _isSaving = false;
          final now = DateTime.now();
          final minutes = now.minute.toString().padLeft(2, '0');
          final seconds = now.second.toString().padLeft(2, '0');
          _saveStatus = "Saved at ${now.hour}:$minutes:$seconds";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStatus = "Save failed";
        });
      }
    }
  }

  Future<void> _deleteNote() async {
    if (_noteId == null) {
      Navigator.pop(context);
      return;
    }

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Note", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete this note?", style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete", style: GoogleFonts.inter(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('student_notes').delete().eq('id', _noteId!);
        _autoSaveTimer?.cancel();
        _hasUnsavedChanges = false; // Prevent auto-save on dispose
        navigator.pop(true); // Return true to indicate deletion
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text("Error deleting note: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _hasUnsavedChanges = true;
        _saveStatus = "Unsaved changes";
      });
      // Trigger instant save for date change
      _saveNote();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.note == null ? "New Note" : "Edit Note",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_noteId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: _deleteNote,
            ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Colors.teal),
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (_hasUnsavedChanges) {
                await _saveNote();
              }
              navigator.pop(true);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status bar (Auto save indicator, Date selector)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Save status
                  Row(
                    children: [
                      Icon(
                        _saveStatus.startsWith("Saved") 
                            ? Icons.cloud_done_outlined 
                            : (_isSaving ? Icons.sync_rounded : Icons.edit_note_rounded),
                        size: 16,
                        color: _saveStatus.startsWith("Saved") ? Colors.green : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _saveStatus,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Date picker trigger
                  InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.teal),
                          const SizedBox(width: 6),
                          Text(
                            "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Title & Description editing fields
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: "Title",
                        hintStyle: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[350],
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: _descController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: "Start typing your note here...",
                          hintStyle: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.grey[400],
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
